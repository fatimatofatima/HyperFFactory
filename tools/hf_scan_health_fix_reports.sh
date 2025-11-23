#!/usr/bin/env bash
# HyperFFactory – Health/Fix/Report Scripts Scanner (Optimized)
# - قراءة فقط
# - نطاق محدود لمجلدات الكود
# - لا يلمس ffactory ولا أي مشاريع خارج HyperFFactory
# - يتحمل عدم وجود نتائج بدون إسقاط السكربتات الإدارية

set -euo pipefail

BASE_DIR="/root/HyperFFactory"
cd "$BASE_DIR"

OUT_DIR="reports/scripts_index"
mkdir -p "$OUT_DIR"

TS="$(date +%Y%m%d_%H%M%S)"
OUT_FILE="$OUT_DIR/hf_health_fix_report_scripts_${TS}.txt"

echo "=== HyperFFactory – Health/Fix/Report Scripts Scanner ==="
echo "BASE_DIR: $BASE_DIR"
echo "OUT_FILE: $OUT_FILE"
echo

# مجلدات الكود التي نهتم بها فقط
SCAN_TARGETS=(
  "tools"
  "scripts"
  "workers"
  "bin"
  "config"
  "db"
)

TMP_ALL="$(mktemp)"
TMP_FILTERED="$(mktemp)"
cleanup() {
  rm -f "$TMP_ALL" "$TMP_FILTERED"
}
trap cleanup EXIT

# 1) تجميع كل السكربتات (sh/py) من مجلدات الكود فقط
> "$TMP_ALL"
for rel in "${SCAN_TARGETS[@]}"; do
  if [[ -d "$rel" ]]; then
    find "$rel" \( -name "*.sh" -o -name "*.py" \) -type f 2>/dev/null >> "$TMP_ALL"
  fi
done

# لو مفيش أي سكربتات في هذه المجلدات
if [[ ! -s "$TMP_ALL" ]]; then
  echo "⚠️ لا توجد سكربتات sh/py داخل مجلدات الكود المحددة."
  echo "⚠️ لا توجد سكربتات sh/py داخل مجلدات الكود المحددة." > "$OUT_FILE"
  exit 0
fi

# 2) فلترة السكربتات الخاصة بـ health/fix/report/backup...
#   ملاحظة: grep هنا قد لا يجد تطابقات، لذلك نسمح له بالفشل بدون إسقاط السكربت
grep -Ei 'check|health|fix|repair|diag|diagnostic|audit|report|backup|snapshot|status|monitor|validate|verify' \
  "$TMP_ALL" 2>/dev/null | sort -u > "$TMP_FILTERED" || true

if [[ ! -s "$TMP_FILTERED" ]]; then
  echo "⚠️ لا توجد سكربتات مطابقة للأنماط المحددة داخل مجلدات الكود."
  echo "⚠️ لا توجد سكربتات مطابقة للأنماط المحددة داخل مجلدات الكود." > "$OUT_FILE"
  exit 0
fi

{
  echo "HyperFFactory – Health/Fix/Report Scripts Index"
  echo "Generated at: $(date +'%Y-%m-%d %H:%M:%S')"
  echo "Base dir   : $BASE_DIR"
  echo
  echo "Legend:"
  echo "  🩺 CHECK  = فحص / صحة / تشخيص / مراقبة"
  echo "  🛠️ FIX    = إصلاح / تنظيف / تصحيح"
  echo "  📊 REPORT = تقارير / ملخصات / Audit / Logs"
  echo "  💾 BACKUP = نسخ احتياطية / Snapshot / Archive"
  echo
  echo "------------------------------------------------------------------------"
  echo

  while IFS= read -r path; do
    name="$(basename "$path")"
    lower="$(echo "$name" | tr '[:upper:]' '[:lower:]')"

    tags=""

    # فحص / صحة / تشخيص
    if [[ "$lower" =~ check|health|diag|diagnostic|status|monitor|validate|verify ]]; then
      tags+="🩺CHECK "
    fi

    # إصلاح / تنظيف
    if [[ "$lower" =~ fix|repair|cleanup|clean ]]; then
      tags+="🛠️FIX "
    fi

    # تقارير / ملخصات
    if [[ "$lower" =~ report|summary|overview|audit|log ]]; then
      tags+="📊REPORT "
    fi

    # نسخ احتياطية / سناب شوت
    if [[ "$lower" =~ backup|snapshot|archive ]]; then
      tags+="💾BACKUP "
    fi

    if [[ -z "$tags" ]]; then
      tags="(other)"
    fi

    echo "$tags -> $path"
  done < "$TMP_FILTERED"
} | tee "$OUT_FILE"

echo
echo "✅ تم إنشاء فهرس سكربتات الفحص/الصحة/الإصلاح/التقارير."
echo "📄 التقرير محفوظ في:"
echo "   $OUT_FILE"
