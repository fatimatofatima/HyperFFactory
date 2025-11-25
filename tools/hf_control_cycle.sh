#!/usr/bin/env bash
# HyperFFactory – Control Cycle
# حلقة تحكم واحدة بسيطة:
# - فحص تكامل الأنظمة (SmartFriend / FFactory) لو السكربت موجود
# - أخذ snapshot للواجهات (Telegram/Web) لو السكربت موجود
# - تقرير جودة مختصر
# - تقرير حوادث مختصر
# - Snapshot سريع للمهام (الريجستري)
#
# ملاحظة:
# - لا يوجد أي cron هنا.
# - يمكنك تشغيله:
#     HF_LOOP_ONCE=1 tools/hf_control_cycle.sh   # دورة واحدة
#     أو
#     SLEEP_SECONDS=300 tools/hf_control_cycle.sh  # حلقة لانهائية كل 5 دقائق (يدويًا أو via service)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

SLEEP_SECONDS="${SLEEP_SECONDS:-300}"

run_cycle() {
  echo "====================================================="
  echo " HyperFFactory – Control Cycle"
  echo " ROOT : $ROOT_DIR"
  echo " TIME : $(date '+%Y-%m-%d %H:%M:%S %z')"
  echo "====================================================="

  echo "[1] Integration health (SmartFriend / FFactory) ..."
  if [[ -x "tools/hf_integration_health_all.sh" ]]; then
    tools/hf_integration_health_all.sh || echo "[WARN] hf_integration_health_all.sh فشل (سيتم متابعة الدورة)" >&2
  else
    echo "[SKIP] لا يوجد tools/hf_integration_health_all.sh (تخطّي)."
  fi

  echo
  echo "[2] Interfaces snapshot (Telegram / Web) ..."
  if [[ -x "tools/hf_interfaces_snapshot.sh" ]]; then
    tools/hf_interfaces_snapshot.sh || echo "[WARN] hf_interfaces_snapshot.sh فشل (سيتم متابعة الدورة)" >&2
  else
    echo "[SKIP] لا يوجد tools/hf_interfaces_snapshot.sh (تخطّي)."
  fi

  echo
  echo "[3] Quality report (ملخّص مختصر)..."
  if [[ -x "bin/hf_quality_report.sh" ]]; then
    bin/hf_quality_report.sh | head -n 40 || echo "[WARN] hf_quality_report.sh فشل (سيتم متابعة الدورة)" >&2
  else
    echo "[SKIP] لا يوجد bin/hf_quality_report.sh (تخطّي)."
  fi

  echo
  echo "[4] Incidents report (ملخّص الحوادث المفتوحة)..."
  if [[ -x "bin/hf_incidents_report.sh" ]]; then
    bin/hf_incidents_report.sh || echo "[WARN] hf_incidents_report.sh فشل (سيتم متابعة الدورة)" >&2
  else
    echo "[SKIP] لا يوجد bin/hf_incidents_report.sh (تخطّي)."
  fi

  echo
  echo "[5] Tasks snapshot (hf_tasks registry – أول 20 صف)..."
  if [[ -x "bin/hf_tasks_admin.sh" ]]; then
    bin/hf_tasks_admin.sh list | head -20 || echo "[WARN] hf_tasks_admin.sh list فشل (سيتم متابعة الدورة)" >&2
  else
    echo "[SKIP] لا يوجد bin/hf_tasks_admin.sh (تخطّي)."
  fi

  echo
  echo "===== Control cycle finished ====="
}

# نمط دورة واحدة (للاختبار أو للاستخدام من cron أو manual)
if [[ "${HF_LOOP_ONCE:-0}" == "1" ]]; then
  run_cycle
  exit 0
fi

# نمط حلقة لا نهائية (للاستخدام مع systemd أو تشغيل يدوي)
while true; do
  run_cycle
  echo
  echo "[Sleep] في انتظار $SLEEP_SECONDS ثانية قبل الدورة التالية..."
  sleep "$SLEEP_SECONDS"
done
