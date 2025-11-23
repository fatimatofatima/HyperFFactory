#!/usr/bin/env bash
# HyperFFactory – Prepare baseline .gitignore block للمصنع الموحّد

set -euo pipefail

ROOT="/root/HyperFFactory"
cd "$ROOT"

GITIGNORE=".gitignore"
TS="$(date '+%Y%m%d_%H%M%S')"
BLOCK_TMP="reports/hf_git_ignore_block_${TS}.txt"
LOG="reports/hf_git_prepare_ignore_block_${TS}.log"

mkdir -p reports

{
  echo "=================================================="
  echo "🧩 HyperFFactory – Prepare Baseline .gitignore Block"
  echo "ROOT : $ROOT"
  echo "TIME : $(date '+%Y-%m-%d %H:%M:%S')"
  echo "=================================================="
} | tee "$LOG"

cat > "$BLOCK_TMP" <<'BLOCK'
# BEGIN HyperFFactory Baseline Ignore
# -------------------------------------------------
# بيئة وتشغيل (لا تُرفع للريبو)
.env
.hyperconfig
.venv/
__pycache__/
*.pyc

# ملفات مؤقتة/نظام تشغيل
*~
.DS_Store

# أرشيفات وسنابشوت خارج قلب المصنع
archive/
HyperFFactory_archives/
imported/
learning/
archive/
collected_scripts_from_opt/
motd_backup_*/
_root_conflicts_*/

# وحدات خارجية مستوردة من /opt أو /var (لا تُدار من هذا الريبو)
imported/opt/report/
imported/opt/COMPLETE_CODE_BACKUP/
imported/opt/deepseek/
imported/opt/sf-venv/
imported/opt/smartfriend-suite/
imported/opt/smartfrind/
imported/opt/secure/

# قواعد بيانات تشغيلية (runtime DBs)
db/**/*.db
db/**/*.db-*
db/**/*.sqlite
db/**/*.sqlite-*
db/**/knowledge_main.db*
db/**/skills.db*
db/meta/*.db
db/meta/*.db-*
db/meta/*.sqlite*

# لوجات وتقارير ثقيلة (يمكن مراجعتها محليًا فقط)
reports/*.log
reports/**/*.log
reports/stack_status/
reports/hf_git_untracked_classified_*.log
reports/hf_assert_unified_tree_*.log
reports/hf_kill_escape_symlinks_*.log
# END HyperFFactory Baseline Ignore
BLOCK

if [[ ! -f "$GITIGNORE" ]]; then
  cp "$BLOCK_TMP" "$GITIGNORE"
  echo "✅ لا يوجد .gitignore سابقاً – تم إنشاء .gitignore جديد بالبلوك الأساسي." | tee -a "$LOG"
  exit 0
fi

if grep -q 'BEGIN HyperFFactory Baseline Ignore' "$GITIGNORE"; then
  echo "ℹ️ البلوك الأساسي موجود مسبقاً داخل .gitignore – لم يتم التعديل." | tee -a "$LOG"
  exit 0
fi

{
  echo ""
  echo "# ---- Added $TS by hf_git_prepare_ignore_block.sh ----"
  cat "$BLOCK_TMP"
} >> "$GITIGNORE"

echo "✅ تم إلحاق بلوك HyperFFactory Baseline Ignore إلى .gitignore." | tee -a "$LOG"
echo "📄 راجع الملف: .gitignore" | tee -a "$LOG"
echo "📄 تم حفظ نسخة من البلوك في: $BLOCK_TMP" | tee -a "$LOG"
