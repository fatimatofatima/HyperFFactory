#!/usr/bin/env bash
# HyperFFactory - Plan SmartFriend legacy services cleanup (READ-ONLY PLAN)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR%/bin}"
REPORT_DIR="$ROOT_DIR/reports"
mkdir -p "$REPORT_DIR"

TS="$(date +%Y%m%d_%H%M%S)"
PLAN="$REPORT_DIR/hf_services_cleanup_plan_${TS}.sh"
SUMMARY="$REPORT_DIR/hf_services_cleanup_summary_${TS}.log"

echo "==================================================" | tee "$SUMMARY"
echo "🧩 HF SERVICES CLEANUP PLAN (READ-ONLY)" | tee -a "$SUMMARY"
echo "📍 Time : $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$SUMMARY"
echo "📂 Root : $ROOT_DIR" | tee -a "$SUMMARY"
echo "==================================================" | tee -a "$SUMMARY"

echo "📦 تجميع قائمة الخدمات من systemd ..." | tee -a "$SUMMARY"

sf_units="$(systemctl list-units 'sf-*.service' --no-legend --all 2>/dev/null | awk '{print $1}' | sort -u || true)"
smartfrind_units="$(systemctl list-units 'smartfrind-*.service' --no-legend --all 2>/dev/null | awk '{print $1}' | sort -u || true)"

{
  echo "#!/usr/bin/env bash"
  echo "# خطة تنظيف الخدمات Legacy الخاصة بـ smartfrind-*"
  echo "# تم إنشاؤها آليًا بواسطة bin/hf_plan_services_cleanup.sh"
  echo "# راجع الأوامر يدويًا قبل التنفيذ."
  echo
  echo "set -euo pipefail"
  echo
} > "$PLAN"

echo >> "$SUMMARY"
echo "--------------------------------------------------" | tee -a "$SUMMARY"
echo "🔹 خدمات SmartFriend Suite (sf-*.service) – للمتابعة اليدوية:" | tee -a "$SUMMARY"

if [[ -n "$sf_units" ]]; then
  while read -r u; do
    [[ -z "$u" ]] && continue
    state="$(systemctl show -p ActiveState -p SubState "$u" 2>/dev/null | tr '\n' ' ' || true)"
    echo "   - $u : $state" | tee -a "$SUMMARY"
  done <<< "$sf_units"
else
  echo "   (لا توجد خدمات sf-*.service)" | tee -a "$SUMMARY"
fi

echo >> "$SUMMARY"
echo "--------------------------------------------------" | tee -a "$SUMMARY"
echo "🔹 خدمات Legacy smartfrind-*.service (مستهدفة للتعطيل في الخطة):" | tee -a "$SUMMARY"

if [[ -n "$smartfrind_units" ]]; then
  while read -r u; do
    [[ -z "$u" ]] && continue
    state="$(systemctl show -p ActiveState -p SubState "$u" 2>/dev/null | tr '\n' ' ' || true)"
    echo "   - $u : $state" | tee -a "$SUMMARY"

    echo "# تعطيل وإيقاف خدمة Legacy: $u" >> "$PLAN"
    echo "systemctl disable --now $u || true" >> "$PLAN"
    echo >> "$PLAN"
  done <<< "$smartfrind_units"
else
  echo "   (لا توجد خدمات smartfrind-*.service)" | tee -a "$SUMMARY"
fi

chmod +x "$PLAN"

echo "--------------------------------------------------" | tee -a "$SUMMARY"
echo "📄 ملف الخطة الجاهز (لا ينفّذ تلقائيًا): $PLAN" | tee -a "$SUMMARY"
echo "✅ انتهى بناء خطة الخدمات." | tee -a "$SUMMARY"
