#!/usr/bin/env bash
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

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

# جمع كل سكربتات الفحص/الصحة/الإصلاح/التقارير/الباك أب
find "$BASE_DIR" \
  \( -name "*.sh" -o -name "*.py" \) -type f 2>/dev/null | \
  grep -Ei 'check|health|fix|repair|diag|diagnostic|audit|report|backup|snapshot|status|monitor|validate|verify' | \
  sort -u > "$TMP"

if [[ ! -s "$TMP" ]]; then
  echo "⚠️ لا توجد سكربتات مطابقة للأنماط المحددة."
  echo "⚠️ لا توجد سكربتات مطابقة للأنماط المحددة." > "$OUT_FILE"
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
  done < "$TMP"
} | tee "$OUT_FILE"

echo
echo "✅ تم إنشاء فهرس سكربتات الفحص/الصحة/الإصلاح/التقارير."
echo "📄 التقرير محفوظ في:"
echo "   $OUT_FILE"
