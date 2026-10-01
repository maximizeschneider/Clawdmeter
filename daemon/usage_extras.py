"""Extra usage stats for the payload: a per-model weekly limit bar (e.g. Fable)
and this calendar month's token count + API-equivalent cost.

Both are additive payload keys; firmware that doesn't know them ignores them,
and the device hides the matching widgets when a key is absent.

  "m"/"mr"/"ml" — per-model weekly limit: utilization %, minutes to reset, label
  "mt"/"mc"     — this month's tokens (input + output + cache write + cache
                  read) and their cost in USD at Anthropic API list prices

The model limit comes from the same OAuth usage endpoint Claude Code's /usage
screen reads. The monthly figures are summed locally from Claude Code's session
transcripts (<config_dir>/projects/**/*.jsonl), so they only cover Claude Code
usage on this machine.
"""

from __future__ import annotations

import datetime
import json
import os
import re
from pathlib import Path

import httpx

OAUTH_USAGE_URL = "https://api.anthropic.com/api/oauth/usage"

# USD per million tokens: (input, output, cache read). Cache writes are priced
# off input: 1.25x for the 5-minute TTL, 2x for the 1-hour TTL. A row applies
# to every model id containing its key; the longest matching key wins, so
# "opus-5-5" beats "opus-5" regardless of order. `price.<key> = in, out, read`
# lines in the daemon config override or extend this table (see
# parse_price_overrides), so a price change needs no code edit or restart.
Price = tuple[float, float, float]
PRICES: dict[str, Price] = {
    "fable-5-1":  (10.0, 50.0, 0.25),
    "mythos-5-1": (10.0, 50.0, 0.25),
    "fable":      (10.0, 50.0, 1.00),   # Fable 5
    "mythos":     (10.0, 50.0, 1.00),   # Mythos 5
    "opus-5-5":   (4.0, 20.0, 0.20),
    "opus-5":     (5.0, 25.0, 0.50),
    "opus-4-8":   (5.0, 25.0, 0.50),
    "opus-4-7":   (5.0, 25.0, 0.50),
    "opus-4-6":   (5.0, 25.0, 0.50),
    "opus-4-5":   (5.0, 25.0, 0.50),
    "opus-4":     (15.0, 75.0, 1.50),   # Opus 4 / 4.1
    "sonnet-5":   (2.0, 10.0, 0.20),    # Sonnet 5 / 5.5
    "sonnet-4":   (3.0, 15.0, 0.30),    # Sonnet 4 / 4.5 / 4.6
    "haiku-4":    (1.0, 5.0, 0.10),     # Haiku 4.5
    "haiku-3-5":  (0.8, 4.0, 0.08),
}


def parse_price_overrides(settings: dict[str, str]) -> dict[str, Price]:
    """`price.<model key> = input, output, cache_read` config lines (USD per
    million tokens). Malformed lines are logged and skipped."""
    out: dict[str, Price] = {}
    for key, val in settings.items():
        if not key.startswith("price."):
            continue
        name = key[len("price."):].strip()
        try:
            nums = tuple(float(x) for x in val.replace(" ", "").split(","))
        except ValueError:
            nums = ()
        if not name or len(nums) != 3 or min(nums) < 0:
            print(f"[usage_extras] ignoring config line {key} = {val!r}; "
                  "expected: input, output, cache_read", flush=True)
            continue
        out[name] = nums  # type: ignore[assignment]
    return out


def price_for(model: str, overrides: dict[str, Price] | None = None) -> Price | None:
    """Price row for a model id: the longest key it contains, config overrides
    winning over built-ins on an equal-length match."""
    m = model.lower()
    best: tuple[int, int, Price] | None = None
    for prio, table in ((0, PRICES), (1, overrides or {})):
        for key, price in table.items():
            if key in m and (best is None or (len(key), prio) > best[:2]):
                best = (len(key), prio, price)
    return best[2] if best else None


# Per-message token counts: (input, output, cache read, 5m write, 1h write)
Counts = tuple[int, int, int, int, int]


def usage_counts(usage: dict) -> Counts:
    write = usage.get("cache_creation_input_tokens") or 0
    split = usage.get("cache_creation") or {}
    w1h = split.get("ephemeral_1h_input_tokens") or 0
    return (usage.get("input_tokens") or 0,
            usage.get("output_tokens") or 0,
            usage.get("cache_read_input_tokens") or 0,
            max(write - w1h, 0),  # no split reported -> treat all writes as 5m
            w1h)


def counts_cost(price: Price, c: Counts) -> float:
    p_in, p_out, p_read = price
    inp, out, read, w5m, w1h = c
    return (inp * p_in + out * p_out + read * p_read
            + w5m * p_in * 1.25 + w1h * p_in * 2.0) / 1_000_000


def usage_cost(model: str, usage: dict, overrides: dict[str, Price] | None = None) -> float:
    """API-equivalent USD cost of one assistant message's `usage` block."""
    price = price_for(model, overrides)
    return counts_cost(price, usage_counts(usage)) if price else 0.0


class MonthlyUsage:
    """Sums this month's tokens and cost from Claude Code transcripts.

    Re-parses only files whose size/mtime changed since the last call, so the
    per-poll cost stays small once the cache is warm. Assistant messages are
    de-duplicated by message id + request id: Claude Code writes one line per
    content block, each repeating the same usage block. Token counts are cached
    per message and priced on every call, so a price change applies at once.
    """

    def __init__(self) -> None:
        # path -> (mtime, size, {month: {dedup_key: (model, counts)}})
        self._files: dict[Path, tuple[float, int, dict[str, dict[str, tuple[str, Counts]]]]] = {}
        self._unknown_models: set[str] = set()

    @staticmethod
    def _parse(path: Path) -> dict[str, dict[str, tuple[str, Counts]]]:
        months: dict[str, dict[str, tuple[str, Counts]]] = {}
        try:
            fh = path.open("r", encoding="utf-8", errors="replace")
        except OSError:
            return months
        with fh:
            for line in fh:
                if '"usage"' not in line:
                    continue
                try:
                    rec = json.loads(line)
                except ValueError:
                    continue
                msg = rec.get("message")
                if not isinstance(msg, dict):
                    continue
                usage = msg.get("usage")
                model = msg.get("model") or ""
                ts = rec.get("timestamp")
                if not isinstance(usage, dict) or not ts or model == "<synthetic>":
                    continue
                try:
                    when = datetime.datetime.fromisoformat(ts.replace("Z", "+00:00"))
                except ValueError:
                    continue
                month = when.astimezone().strftime("%Y-%m")  # local calendar month
                key = f"{msg.get('id')}:{rec.get('requestId')}"
                if msg.get("id") is None:
                    key = f"{rec.get('uuid')}"
                months.setdefault(month, {})[key] = (model, usage_counts(usage))
        return months

    def totals(self, config_dirs: list[Path], now: datetime.datetime | None = None,
               overrides: dict[str, Price] | None = None) -> tuple[int, float]:
        now = now or datetime.datetime.now().astimezone()
        month = now.strftime("%Y-%m")
        month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0).timestamp()
        seen: set[Path] = set()
        merged: dict[str, tuple[str, Counts]] = {}
        for d in config_dirs:
            root = d / "projects"
            if not root.is_dir():
                continue
            for path in root.rglob("*.jsonl"):
                try:
                    st = path.stat()
                except OSError:
                    continue
                seen.add(path)
                if st.st_mtime < month_start:
                    continue  # untouched since before this month
                cached = self._files.get(path)
                if cached is None or cached[0] != st.st_mtime or cached[1] != st.st_size:
                    cached = (st.st_mtime, st.st_size, self._parse(path))
                    self._files[path] = cached
                merged.update(cached[2].get(month, {}))
        for gone in set(self._files) - seen:
            del self._files[gone]
        tokens = 0
        cost = 0.0
        prices: dict[str, Price | None] = {}
        for model, counts in merged.values():
            tokens += sum(counts)
            if model not in prices:
                prices[model] = price_for(model, overrides)
                if prices[model] is None and model not in self._unknown_models:
                    self._unknown_models.add(model)
                    print(f"[usage_extras] no price for model {model!r}; its tokens "
                          "count but add $0 (add a price.<model> line to the config)",
                          flush=True)
            if prices[model]:
                cost += counts_cost(prices[model], counts)
        return tokens, cost


def _reset_minutes(resets_at, now: datetime.datetime) -> int:
    if not resets_at:
        return 0
    try:
        when = datetime.datetime.fromisoformat(str(resets_at).replace("Z", "+00:00"))
    except ValueError:
        return 0
    mins = (when - now).total_seconds() / 60
    return int(round(mins)) if mins > 0 else 0


def pick_model_limit(usage: dict, wanted: str) -> tuple[str, dict] | None:
    """Find the per-model weekly bucket in an /api/oauth/usage response.

    `wanted` is either an exact key (e.g. "seven_day_fable") or a model word
    ("fable") matched against keys that start with "seven_day_".
    """
    if not isinstance(usage, dict):
        return None
    if isinstance(usage.get(wanted), dict):
        return wanted, usage[wanted]
    w = wanted.lower()
    for key, val in usage.items():
        if key.startswith("seven_day_") and w in key.lower() and isinstance(val, dict):
            return key, val
    return None


_logged_keys = False
# Last good result + when it was fetched, so one failed call doesn't blink the
# bar off for a poll cycle. Reused (with the countdown aged) for STALE_OK_S.
_last: tuple[float, dict] | None = None
STALE_OK_S = 600


def _fallback() -> dict:
    if _last is None:
        return {}
    at, fields = _last
    age = datetime.datetime.now().timestamp() - at
    if age > STALE_OK_S:
        return {}
    aged = dict(fields)
    aged["mr"] = max(int(aged["mr"] - age // 60), 0)
    return aged


async def fetch_model_limit(token: str, wanted: str, label: str,
                            user_agent: str) -> dict:
    """Payload fields {"m","mr","ml"} for the configured model's weekly limit,
    or {} when the endpoint doesn't report one (the device then hides the bar).
    """
    global _logged_keys, _last
    headers = {
        "Authorization": f"Bearer {token}",
        "anthropic-beta": "oauth-2025-04-20",
        "User-Agent": user_agent,
    }
    try:
        async with httpx.AsyncClient(timeout=15.0) as http:
            resp = await http.get(OAUTH_USAGE_URL, headers=headers)
    except httpx.HTTPError as e:
        print(f"[usage_extras] usage endpoint failed: {e}", flush=True)
        return _fallback()
    if resp.status_code >= 400:
        print(f"[usage_extras] usage endpoint HTTP {resp.status_code}", flush=True)
        return _fallback()
    try:
        data = resp.json()
    except ValueError:
        return _fallback()
    found = pick_model_limit(data, wanted)
    if found is None:
        if not _logged_keys:
            _logged_keys = True
            keys = sorted(k for k, v in data.items() if isinstance(v, dict)) \
                if isinstance(data, dict) else []
            print(f"[usage_extras] no weekly limit matching {wanted!r}; "
                  f"available: {keys} (set model_limit = <key> in the config)",
                  flush=True)
        return {}
    _key, bucket = found
    try:
        util = float(bucket.get("utilization") or 0)
    except (TypeError, ValueError):
        util = 0.0
    now = datetime.datetime.now(datetime.timezone.utc)
    fields = {
        "m": int(round(util)),          # endpoint reports 0-100 already
        "mr": _reset_minutes(bucket.get("resets_at"), now),
        "ml": label[:11],
    }
    _last = (now.timestamp(), fields)
    return fields


def read_settings(config_file: Path) -> dict[str, str]:
    """`key = value` lines from the daemon config, lower-cased keys."""
    out: dict[str, str] = {}
    try:
        for line in config_file.read_text().splitlines():
            line = line.split("#", 1)[0].strip()
            if "=" in line:
                k, v = line.split("=", 1)
                out[k.strip().lower()] = v.strip()
    except OSError:
        pass
    return out


def is_off(value: str | None) -> bool:
    return (value or "").strip().lower() in ("off", "no", "false", "0", "none")


def label_for(wanted: str) -> str:
    """"seven_day_fable" / "fable" -> "Fable"."""
    word = re.sub(r"^seven_day_", "", wanted.strip(), flags=re.I)
    return word.replace("_", " ").title() or "Model"


def env_or(settings: dict[str, str], key: str, default: str) -> str:
    return os.environ.get(key.upper()) or settings.get(key) or default
