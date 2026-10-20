"""HTTP relay for Wi-Fi builds: serves the same JSON payload the daemon sends over BLE.

Runs on a server (deployed with ship), so the device keeps updating while the Mac is off.

  GET  /healthz            liveness, no auth
  GET  /u/<key>            usage payload (polled on demand, cached CACHE_S)
  POST /u/<key>/month      {"mt": tokens, "mc": usd} pushed by the Mac daemon; the
                           server can't see local transcripts, so it relays the Mac's total

Env (from /etc/ship/clawdmeter.env):
  CLAUDE_CODE_OAUTH_TOKEN  long-lived token from `claude setup-token`
  RELAY_KEY                shared secret in the URL path
  TZ                       e.g. Europe/Berlin, for the clock fields
  CLOCK                    24 | 12 | off (default 24)
  MODEL_LIMIT              weekly bucket for the third bar (default fable; off = hide)
"""

import asyncio
import hmac
import json
import os
import time
from pathlib import Path

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse

from daemon import claude_usage_daemon as d
from daemon import usage_extras

CACHE_S = 60
TOKEN = os.environ["CLAUDE_CODE_OAUTH_TOKEN"]
KEY = os.environ["RELAY_KEY"]
MONTH_FILE = Path(os.environ.get("DATA_DIR", ".")) / "month.json"

app = FastAPI(docs_url=None, redoc_url=None, openapi_url=None)
_lock = asyncio.Lock()
_cache: tuple[float, dict] | None = None


def _auth(key: str) -> None:
    if not hmac.compare_digest(key, KEY):
        raise HTTPException(404)  # same answer as an unknown path


def _this_month() -> str:
    return time.strftime("%Y-%m")


def _month_fields() -> dict:
    """The Mac's last pushed total, only while it's still the same calendar month."""
    try:
        saved = json.loads(MONTH_FILE.read_text())
    except (OSError, ValueError):
        return {}
    if saved.get("month") != _this_month():
        return {}
    return {"mt": saved["mt"], "mc": saved["mc"]}


async def _poll() -> dict | None:
    try:
        payload = await d.poll_api(TOKEN)
    except d.TokenExpired:
        return None
    if payload is None:
        return None
    wanted = os.environ.get("MODEL_LIMIT", "fable")
    if payload.get("acct") == "pro" and not usage_extras.is_off(wanted):
        payload.update(await usage_extras.fetch_model_limit(TOKEN, wanted, usage_extras.label_for(wanted)))
    return payload


@app.get("/healthz")
def healthz():
    return {"ok": True}


@app.get("/u/{key}")
async def usage(key: str):
    global _cache
    _auth(key)
    async with _lock:  # one upstream poll at a time; concurrent callers share it
        if _cache is None or time.time() - _cache[0] > CACHE_S:
            payload = await _poll()
            if payload is None:
                return JSONResponse({"ok": False}, status_code=503)
            _cache = (time.time(), payload)
        payload = dict(_cache[1])
    clock = os.environ.get("CLOCK", "24")
    if clock != "off":
        # Same shape as the daemon's clock fields: local wall-clock epoch, recomputed per request
        payload["t"] = int(time.time()) + time.localtime().tm_gmtoff
        payload["tf"] = 12 if clock == "12" else 24
    payload.update(_month_fields())
    return payload


@app.post("/u/{key}/month")
async def month(key: str, request: Request):
    _auth(key)
    body = await request.json()
    try:
        mt, mc = float(body["mt"]), float(body["mc"])
    except (KeyError, TypeError, ValueError):
        raise HTTPException(422, "need numeric mt and mc")
    tmp = MONTH_FILE.with_suffix(".tmp")
    tmp.write_text(json.dumps({"month": _this_month(), "mt": mt, "mc": mc}))
    tmp.replace(MONTH_FILE)  # atomic: a reader never sees a half-written file
    return {"ok": True}
