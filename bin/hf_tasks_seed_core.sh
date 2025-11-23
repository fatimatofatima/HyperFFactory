#!/usr/bin/env bash
# HyperFFactory - Seed Core Tasks (idempotent)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR%/bin}"
META_DIR="$ROOT_DIR/db/meta"
DB="$META_DIR/hf_tasks.db"
TASK_ADD="$ROOT_DIR/bin/hf_tasks_add.sh"

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "❌ sqlite3 غير مثبت. ثبّت sqlite3 ثم أعد المحاولة." >&2
  exit 1
fi

if [[ ! -f "$DB" ]]; then
  echo "❌ قاعدة بيانات المهام غير موجودة: $DB" >&2
  echo "▶ شغّل أولاً: bin/hf_tasks_init.sh" >&2
  exit 1
fi

if [[ ! -x "$TASK_ADD" ]]; then
  echo "❌ سكربت إضافة المهام غير موجود أو غير قابل للتنفيذ: $TASK_ADD" >&2
  exit 1
fi

check_or_add() {
  local ACTOR="$1"
  local SCOPE="$2"
  local STATUS="$3"
  local PRIORITY="$4"
  local TITLE="$5"

  local COUNT
  COUNT="$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE title = '$TITLE';")"

  if [[ "$COUNT" -eq 0 ]]; then
    echo "➕ إضافة مهمة: $TITLE"
    "$TASK_ADD" "$ACTOR" "$SCOPE" "$STATUS" "$PRIORITY" "$TITLE" >/dev/null
  else
    echo "✔️ موجودة مسبقًا: $TITLE"
  fi
}

echo "=================================================="
echo "🧱 HyperFFactory – Seed Core Tasks"
echo "📍 DB : $DB"
echo "=================================================="

# 1) تكامل SmartFriend
check_or_add \
  "hyper_brain_controller" \
  "integration_smartfriend" \
  "PLANNED" \
  1 \
  "تصميم واجهة تكامل SmartFriend الرسمية (Health/Memory/Knowledge/Gateway)"

# 2) تكامل FFactory
check_or_add \
  "hyper_brain_controller" \
  "integration_ffactory" \
  "PLANNED" \
  1 \
  "تصميم واجهة تكامل FFactory الرسمية (AI/ASR/Tools)"

# 3) سياسة النسخ الاحتياطي الموحد
check_or_add \
  "hyper_brain_controller" \
  "backup_policy" \
  "PLANNED" \
  1 \
  "توحيد مسارات النسخ الاحتياطي بين HyperFFactory و SmartFriend و FFactory"

# 4) نظام الجودة
check_or_add \
  "hyper_quality_manager" \
  "quality_system" \
  "PLANNED" \
  2 \
  "إنشاء hf_quality.db وتعريف مؤشرات الجودة وفحوصاتها الدورية"

# 5) نظام الأخطاء
check_or_add \
  "hyper_error_manager" \
  "errors_system" \
  "PLANNED" \
  2 \
  "إنشاء hf_errors.db وتسجيل الأخطاء مع مستوى الخطورة"

# 6) نظام التعلّم/الخبرة
check_or_add \
  "hyper_learning_manager" \
  "learning_system" \
  "PLANNED" \
  2 \
  "إنشاء hf_learning.db وربطه مع مهام التعلّم والخبرة"

# 7) جدولة فحوصات الصحة والشجرة
check_or_add \
  "hyper_guard" \
  "monitoring" \
  "PLANNED" \
  1 \
  "جدولة hf_health_all.sh و hf_assert_unified_tree.sh عبر cron/systemd-timer"

# 8) لوحة تحكم CLI
check_or_add \
  "hyper_cli" \
  "dashboard" \
  "PLANNED" \
  3 \
  "تطوير hf_dashboard_cli.sh لعرض الحالة العامة والمهام والتقارير"

echo "=================================================="
echo "✅ انتهاء Seed Core Tasks."
echo "=================================================="

# تسجيل التقدّم (اختياري)
PROG_LOG="$ROOT_DIR/bin/hf_progress_log.sh"
if [[ -x "$PROG_LOG" ]]; then
  "$PROG_LOG" "hf_tasks_seed_core" "INFO" "seed core tasks"
fi

exit 0
