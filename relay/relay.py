"""HTTP relay for Wi-Fi builds: serves the same JSON payload the daemon sends over BLE.

Runs on a server (deployed with ship), so the device keeps updating while the Mac is off.

  GET  /healthz            liveness, no auth
  GET  /u/<key>            usage payload (polled on demand, cached CACHE_S)
  POST /u/<key>/push       pushed by the Mac daemon, for what the server can't get itself:
                           {"mt", "mc"}  month totals (from local transcripts)
                           {"m", "ml", "m_reset_at"}  model limit (needs user:profile scope,
                           which the setup-token lacks); hidden after MODEL_MAX_AGE_S

Env (from /etc/ship/clawdmeter.env):
  CLAUDE_CODE_OAUTH_TOKEN  long-lived token from `claude setup-token`
  RELAY_KEY                shared secret in the URL path
  TZ                       e.g. Europe/Berlin, for the clock fields
  CLOCK                    24 | 12 | off (default 24)
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

CACHE_S = 60
MODEL_MAX_AGE_S = 6 * 3600  # Mac off longer than this: the frozen model % would mislead
TOKEN = os.environ["CLAUDE_CODE_OAUTH_TOKEN"]
KEY = os.environ["RELAY_KEY"]
PUSH_FILE = Path(os.environ.get("DATA_DIR", ".")) / "push.json"

app = FastAPI(docs_url=None, redoc_url=None, openapi_url=None)
_lock = asyncio.Lock()
_cache: tuple[float, dict] | None = None


def _auth(key: str) -> None:
    if not hmac.compare_digest(key, KEY):
        raise HTTPException(404)  # same answer as an unknown path


def _this_month() -> str:
    return time.strftime("%Y-%m")


def _pushed_fields() -> dict:
    """The Mac's last push, minus whatever has gone stale."""
    try:
        saved = json.loads(PUSH_FILE.read_text())
    except (OSError, ValueError):
        return {}
    out = {}
    if saved.get("month") == _this_month() and "mt" in saved:
        out |= {"mt": saved["mt"], "mc": saved["mc"]}
    now = time.time()
    fresh = now - saved.get("at", 0) < MODEL_MAX_AGE_S
    if "m" in saved and fresh and saved.get("m_reset_at", 0) > now:
        out |= {"m": saved["m"], "ml": saved["ml"], "mr": round((saved["m_reset_at"] - now) / 60)}
    return out


async def _poll() -> dict | None:
    try:
        return await d.poll_api(TOKEN)
    except d.TokenExpired:
        return None


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
    payload.update(_pushed_fields())
    return payload


@app.post("/u/{key}/push")
async def push(key: str, request: Request):
    _auth(key)
    body = await request.json()
    saved = {"month": _this_month(), "at": int(time.time())}
    try:
        if "mt" in body:
            saved |= {"mt": float(body["mt"]), "mc": float(body["mc"])}
        if "m" in body:
            saved |= {"m": float(body["m"]), "ml": str(body["ml"])[:11], "m_reset_at": int(body["m_reset_at"])}
    except (KeyError, TypeError, ValueError):
        raise HTTPException(422, "mt+mc and m+ml+m_reset_at must come in pairs, numeric")
    tmp = PUSH_FILE.with_suffix(".tmp")
    tmp.write_text(json.dumps(saved))
    tmp.replace(PUSH_FILE)  # atomic: a reader never sees a half-written file
    return {"ok": True}
