#!/usr/bin/env python3
"""
HyperFFactory – Unified Health Center (Stub)

- نقطة صحة موحّدة تقرأ حالة SmartFriend Suite (وعملياً يمكن توسيعها لاحقاً).
- لا تفشل لو health_gate غير متوافق؛ تسجّل الحالة كـ error في الـ JSON فقط.
"""

import json
import sys
from datetime import datetime
from pathlib import Path
from typing import Any, Dict


def smartfriend_health() -> Dict[str, Any]:
    base = Path("/opt/smartfriend-suite")
    ops_path = base / "ops"
    result: Dict[str, Any] = {
        "name": "smartfriend_suite",
        "status": "unknown",
        "details": {},
    }

    if not ops_path.exists():
        result["status"] = "missing"
        result["details"] = {"reason": "ops/ غير موجودة تحت /opt/smartfriend-suite"}
        return result

    sys.path.insert(0, str(base))
    try:
        from ops import health_gate  # type: ignore
    except Exception as exc:  # noqa: BLE001
        result["status"] = "error"
        result["details"] = {
            "reason": "import_error",
            "message": repr(exc),
        }
        return result

    # نحاول استدعاء دالة صحّة لو وجدت
    for attr in ("get_health", "run_health", "main"):
        fn = getattr(health_gate, attr, None)
        if callable(fn):
            try:
                value = fn()  # type: ignore[misc]
                result["status"] = "ok"
                result["details"] = {
                    "entrypoint": attr,
                    "payload": value,
                }
                return result
            except Exception as exc:  # noqa: BLE001
                result["status"] = "error"
                result["details"] = {
                    "reason": "call_error",
                    "entrypoint": attr,
                    "message": repr(exc),
                }
                return result

    result["status"] = "error"
    result["details"] = {
        "reason": "no_known_entrypoint",
        "hint": "لم يتم العثور على get_health/run_health/main في health_gate",
    }
    return result


def main() -> None:
    now = datetime.utcnow().isoformat()
    health_payload = {
        "time_utc": now,
        "source": "HyperFFactory Unified Health",
        "components": [
            smartfriend_health(),
            # يمكن لاحقاً إضافة ffactory / أنظمة أخرى هنا
        ],
    }
    print(json.dumps(health_payload, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
