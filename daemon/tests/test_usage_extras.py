#!/usr/bin/env python3
"""Tests for daemon/usage_extras.py: per-model limit lookup and the monthly
token/cost roll-up from Claude Code transcripts.

Run: python -m pytest daemon/tests/test_usage_extras.py -x -q
"""
import datetime
import json
import os

from daemon import usage_extras as ux


def _assistant(msg_id, req_id, ts, model, **usage):
    return json.dumps({
        "type": "assistant", "requestId": req_id, "timestamp": ts,
        "message": {"id": msg_id, "model": model, "usage": usage},
    })


def test_price_lookup_prefers_specific_ids():
    assert ux.price_for("claude-fable-5-1") == (10.0, 50.0, 0.25)
    assert ux.price_for("claude-fable-5") == (10.0, 50.0, 1.00)
    assert ux.price_for("claude-opus-5-5") == (4.0, 20.0, 0.20)
    assert ux.price_for("claude-opus-4-1-20250805") == (15.0, 75.0, 1.50)
    assert ux.price_for("claude-sonnet-4-5-20250929") == (3.0, 15.0, 0.30)
    assert ux.price_for("claude-haiku-4-5-20251001") == (1.0, 5.0, 0.10)
    assert ux.price_for("some-other-model") is None


def test_usage_cost_splits_cache_write_ttls():
    # 1M of each bucket on Opus 5.5 ($4 in / $20 out / $0.20 read):
    # in 4 + out 20 + read 0.2 + 5m write 1M*4*1.25=5 + 1h write 1M*4*2=8
    cost = ux.usage_cost("claude-opus-5-5", {
        "input_tokens": 1_000_000, "output_tokens": 1_000_000,
        "cache_read_input_tokens": 1_000_000,
        "cache_creation_input_tokens": 2_000_000,
        "cache_creation": {"ephemeral_5m_input_tokens": 1_000_000,
                           "ephemeral_1h_input_tokens": 1_000_000},
    })
    assert abs(cost - 37.2) < 1e-9


def test_monthly_totals_dedupes_and_filters_by_month(tmp_path):
    proj = tmp_path / "projects" / "-home-me-repo"
    proj.mkdir(parents=True)
    now = datetime.datetime(2026, 10, 15, 12, 0).astimezone()
    this_month = now.replace(day=2).astimezone(datetime.timezone.utc).isoformat()
    last_month = now.replace(month=9, day=20).astimezone(datetime.timezone.utc).isoformat()
    usage = dict(input_tokens=100, output_tokens=50,
                 cache_read_input_tokens=1000, cache_creation_input_tokens=200)
    lines = [
        # Same message written twice (one line per content block) -> counted once
        _assistant("msg_1", "req_1", this_month, "claude-fable-5-1", **usage),
        _assistant("msg_1", "req_1", this_month, "claude-fable-5-1", **usage),
        _assistant("msg_2", "req_2", this_month, "claude-sonnet-5-5", **usage),
        _assistant("msg_3", "req_3", last_month, "claude-fable-5-1", **usage),
        _assistant("msg_4", "req_4", this_month, "<synthetic>", **usage),
        json.dumps({"type": "user", "timestamp": this_month, "message": {"content": "hi"}}),
        "not json",
    ]
    f = proj / "session.jsonl"
    f.write_text("\n".join(lines) + "\n")
    os.utime(f, (now.timestamp(), now.timestamp()))

    tokens, cost = ux.MonthlyUsage().totals([tmp_path], now=now)
    assert tokens == 2 * 1350
    expected = (ux.usage_cost("claude-fable-5-1", usage)
                + ux.usage_cost("claude-sonnet-5-5", usage))
    assert abs(cost - expected) < 1e-12


def test_monthly_totals_reparses_only_changed_files(tmp_path):
    proj = tmp_path / "projects" / "p"
    proj.mkdir(parents=True)
    now = datetime.datetime.now().astimezone()
    ts = now.astimezone(datetime.timezone.utc).isoformat()
    f = proj / "s.jsonl"
    f.write_text(_assistant("a", "r", ts, "claude-opus-5-5", input_tokens=10) + "\n")
    mu = ux.MonthlyUsage()
    assert mu.totals([tmp_path], now=now)[0] == 10
    with f.open("a") as fh:
        fh.write(_assistant("b", "r2", ts, "claude-opus-5-5", input_tokens=5) + "\n")
    assert mu.totals([tmp_path], now=now)[0] == 15
    f.unlink()
    assert mu.totals([tmp_path], now=now)[0] == 0


def test_pick_model_limit_by_word_or_exact_key():
    usage = {
        "five_hour": {"utilization": 10, "resets_at": None},
        "seven_day": {"utilization": 20, "resets_at": None},
        "seven_day_opus": None,
        "seven_day_fable": {"utilization": 61.4, "resets_at": "2026-10-05T10:00:00Z"},
    }
    assert ux.pick_model_limit(usage, "fable")[0] == "seven_day_fable"
    assert ux.pick_model_limit(usage, "seven_day_fable")[0] == "seven_day_fable"
    assert ux.pick_model_limit(usage, "opus") is None   # null bucket
    assert ux.pick_model_limit(usage, "sonnet") is None


def test_label_and_off_switch():
    assert ux.label_for("fable") == "Fable"
    assert ux.label_for("seven_day_fable") == "Fable"
    assert ux.is_off("off") and ux.is_off("0") and not ux.is_off("fable")


def test_add_extra_fields_respects_config(tmp_path, monkeypatch):
    """The daemon adds m/mr/ml + mt/mc for Pro/Max payloads, honours
    `model_limit = off` / `monthly = off`, and skips Enterprise payloads."""
    import asyncio
    import daemon.claude_usage_daemon as d

    async def fake_fetch(token, wanted, label, ua):
        return {"m": 61, "mr": 100, "ml": label}

    monkeypatch.setattr(ux, "fetch_model_limit", fake_fetch)
    monkeypatch.setattr(d._MONTHLY, "totals", lambda dirs: (1234, 5.678))
    cfg = tmp_path / "config"
    monkeypatch.setattr(d, "CONFIG_FILE", cfg)

    p = {"s": 1, "acct": "pro"}
    asyncio.run(d.add_extra_fields(p, "tok", [tmp_path]))
    assert p["m"] == 61 and p["ml"] == "Fable" and p["mt"] == 1234 and p["mc"] == 5.68

    cfg.write_text("model_limit = off\nmonthly = off\n")
    p = {"s": 1, "acct": "pro"}
    asyncio.run(d.add_extra_fields(p, "tok", [tmp_path]))
    assert "m" not in p and "mt" not in p

    cfg.write_text("")
    p = {"s": 1, "acct": "ent"}
    asyncio.run(d.add_extra_fields(p, "tok", [tmp_path]))
    assert "m" not in p and "mt" not in p


def test_model_limit_survives_one_failed_fetch(monkeypatch):
    """A transient endpoint failure reuses the last good value (countdown aged)
    instead of hiding the bar; an old value expires."""
    import asyncio
    import time

    class Resp:
        def __init__(self, code, body=None):
            self.status_code, self._body = code, body

        def json(self):
            return self._body

    replies = []

    class Client:
        def __init__(self, *a, **k):
            pass

        async def __aenter__(self):
            return self

        async def __aexit__(self, *a):
            return False

        async def get(self, *a, **k):
            return replies.pop(0)

    monkeypatch.setattr(ux.httpx, "AsyncClient", Client)
    monkeypatch.setattr(ux, "_last", None)
    reset = datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(hours=2)
    replies.append(Resp(200, {"seven_day_fable": {"utilization": 40,
                                                  "resets_at": reset.isoformat()}}))
    ok = asyncio.run(ux.fetch_model_limit("t", "fable", "Fable", "ua"))
    assert ok["m"] == 40 and 118 <= ok["mr"] <= 120

    replies.append(Resp(429))
    assert asyncio.run(ux.fetch_model_limit("t", "fable", "Fable", "ua"))["m"] == 40

    monkeypatch.setattr(ux, "_last", (time.time() - ux.STALE_OK_S - 1, ok))
    replies.append(Resp(500))
    assert asyncio.run(ux.fetch_model_limit("t", "fable", "Fable", "ua")) == {}
