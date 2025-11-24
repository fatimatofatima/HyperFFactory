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
