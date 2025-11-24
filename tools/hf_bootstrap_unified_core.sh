#!/usr/bin/env bash
# HyperFFactory – Bootstrap unified core (Tree Policy + Health stubs)
# - ينشئ ملفات النواة المفقودة:
#   * /root/HyperFFactory/bin/hf_assert_unified_tree.sh
#   * /root/HyperFFactory/bin/hf_guard.sh
#   * /root/HyperFFactory/ops/run_health.py   (Unified Health)
#   * /opt/smartfriend-suite/bin/sf-service-health (تكامل SmartFriend)
# - لا يلمس /opt/ffactory

set -Eeuo pipefail

ROOT="/root/HyperFFactory"
SUITE_ROOT="/opt/smartfriend-suite"
REPORT_DIR="$ROOT/reports"
DB_DIR="$ROOT/db/meta"
BIN_DIR="$ROOT/bin"
OPS_DIR="$ROOT/ops"

TS="$(date +%Y%m%d_%H%M%S)"
LOG="$REPORT_DIR/hf_bootstrap_unified_core_${TS}.log"

mkdir -p "$REPORT_DIR" "$DB_DIR" "$BIN_DIR" "$OPS_DIR"

log() {
  echo "[$(date '+%F %T')] $*" | tee -a "$LOG"
}

log "=================================================="
log "HyperFFactory – Bootstrap Unified Core"
log "Time : $TS"
log "ROOT : $ROOT"
log "SUITE: $SUITE_ROOT"
log "Log  : $LOG"
log "=================================================="

########################################
# 1) hf_assert_unified_tree.sh
########################################
log "1) كتابة bin/hf_assert_unified_tree.sh"

cat > "$BIN_DIR/hf_assert_unified_tree.sh" <<'SHEOF'
#!/usr/bin/env bash
# HyperFFactory – Assert Unified Tree Policy
# - يتأكد أن كل شيء داخل /root/HyperFFactory مطابق للسياسة:
#   * لا symlink يهرب خارج الجذر
#   * وجود opt/ داخلي
#   * تسجيل النتائج في reports/ و db/meta/hf_changes.db (لو sqlite3 متاح)

set -Eeuo pipefail

ROOT="/root/HyperFFactory"
REPORT_DIR="$ROOT/reports"
DB_DIR="$ROOT/db/meta"
DB_FILE="$DB_DIR/hf_changes.db"

TS="$(date +%Y%m%d_%H%M%S)"
LOG="$REPORT_DIR/hf_assert_unified_tree_${TS}.log"

mkdir -p "$REPORT_DIR" "$DB_DIR"

log() {
  echo "[$(date '+%F %T')] $*" | tee -a "$LOG"
}

log "================ ASSERT UNIFIED TREE ================"
log "Time : $TS"
log "Root : $ROOT"
log "Log  : $LOG"
log "===================================================="

# 1) تأكيد وجود opt/ داخلي
if [ -d "$ROOT/opt" ]; then
  log "✓ موجود: $ROOT/opt"
else
  log "⚠️ غير موجود: $ROOT/opt – سيتم إنشاؤه الآن (متطلب سياسة الهيكل الموحّد)"
  mkdir -p "$ROOT/opt"
  log "✓ تم إنشاء: $ROOT/opt"
fi

VIOLATIONS=0

# 2) فحص symlink هاربة (Escape Pointers)
log "🔍 فحص symlinks داخل $ROOT"

while IFS= read -r link; do
  target="$(readlink -f "$link" || true)"
  if [ -z "$target" ]; then
    log "⚠️ symlink تالف: $link"
    VIOLATIONS=$((VIOLATIONS+1))
    continue
  fi
  case "$target" in
    "$ROOT"/*)
      log "✓ symlink آمن: $link -> $target"
      ;;
    *)
      log "❌ SYMLINK VIOLATION: $link -> $target (خارج الجذر)"
      VIOLATIONS=$((VIOLATIONS+1))
      ;;
  esac
done < <(find "$ROOT" -xtype l 2>/dev/null | sort)

log "🔎 عدد الانتهاكات المكتشفة: $VIOLATIONS"

# 3) تسجيل في SQLite (اختياري)
if command -v sqlite3 >/dev/null 2>&1; then
  sqlite3 "$DB_FILE" <<SQL
CREATE TABLE IF NOT EXISTS hf_changes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ts TEXT NOT NULL,
  actor TEXT NOT NULL,
  scope TEXT NOT NULL,
  status TEXT NOT NULL,
  details TEXT
);
INSERT INTO hf_changes (ts, actor, scope, status, details)
VALUES (
  '$TS',
  'hf_assert_unified_tree',
  'tree_policy',
  CASE WHEN $VIOLATIONS = 0 THEN 'OK' ELSE 'VIOLATIONS' END,
  'violations='$VIOLATIONS
);
SQL
  log "✓ تم تسجيل النتيجة في $DB_FILE (hf_changes)"
else
  log "ℹ️ sqlite3 غير متاح – سيتم الاكتفاء بالتقرير النصي فقط"
fi

if [ "$VIOLATIONS" -eq 0 ]; then
  log "✅ Unified Tree Policy سارية – لا توجد انتهاكات."
  exit 0
else
  log "❌ Unified Tree Policy – توجد $VIOLATIONS انتهاكات (راجع اللوج)."
  exit 1
fi
SHEOF

chmod +x "$BIN_DIR/hf_assert_unified_tree.sh"

########################################
# 2) hf_guard.sh
########################################
log "2) كتابة bin/hf_guard.sh"

cat > "$BIN_DIR/hf_guard.sh" <<'SHEOF'
#!/usr/bin/env bash
# HyperFFactory – Guard Script
# - حارس سريع يشغّل فحوصات السياسة الأساسية (الآن: tree policy)

set -Eeuo pipefail

ROOT="/root/HyperFFactory"
BIN_DIR="$ROOT/bin"

TS="$(date +%Y%m%d_%H%M%S)"

echo "=================================================="
echo "HyperFFactory – Guard"
echo "Time : $TS"
echo "Root : $ROOT"
echo "=================================================="

if "$BIN_DIR/hf_assert_unified_tree.sh"; then
  echo "✅ Tree Policy OK"
else
  echo "❌ Tree Policy Violations – راجع reports/hf_assert_unified_tree_*.log"
fi
SHEOF

chmod +x "$BIN_DIR/hf_guard.sh"

########################################
# 3) Unified Health – /root/HyperFFactory/ops/run_health.py
########################################
log "3) كتابة ops/run_health.py (Unified Health stub)"

cat > "$OPS_DIR/run_health.py" <<'PYEOF'
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
PYEOF

chmod +x "$OPS_DIR/run_health.py"

########################################
# 4) /opt/smartfriend-suite/bin/sf-service-health
########################################
log "4) كتابة /opt/smartfriend-suite/bin/sf-service-health (تكامل مع SmartFriend)"

mkdir -p "$SUITE_ROOT/bin"

cat > "$SUITE_ROOT/bin/sf-service-health" <<'SHEOF'
#!/usr/bin/env bash
# SmartFriend Suite – Service Health CLI
# واجهة بسيطة تستدعي مركز الصحّة الموحّد في HyperFFactory
# مع تركّز على SmartFriend (يمكن توسيعها لاحقاً).

set -Eeuo pipefail

HF_ROOT="/root/HyperFFactory"
HF_HEALTH="$HF_ROOT/ops/run_health.py"

if [ ! -x "$HF_HEALTH" ]; then
  echo "❌ Unified health script غير موجود أو غير قابل للتنفيذ: $HF_HEALTH" >&2
  exit 1
fi

python3 "$HF_HEALTH"
SHEOF

chmod +x "$SUITE_ROOT/bin/sf-service-health"

log "5) (اختياري) تجربة أوامر الصحّة"

log "   - Unified Health: python3 $OPS_DIR/run_health.py"
log "   - SmartFriend Health CLI: $SUITE_ROOT/bin/sf-service-health"

log "=================================================="
log "DONE – hf_bootstrap_unified_core"
log "Report: $LOG"
log "=================================================="
