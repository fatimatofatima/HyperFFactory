#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

LOG_TAG="[SF-DECISION-V2]"
OUT_DIR="/opt/smartfriend-suite/reports"
mkdir -p "$OUT_DIR"

echo "${LOG_TAG} البحث عن أحدث ملف قرارات (v1)..."
SRC_DEC="$(ls -1 ${OUT_DIR}/sf_suite_service_decisions_*.tsv 2>/dev/null | sort | tail -n 1 || true)"

if [[ -z "${SRC_DEC}" ]] || [[ ! -f "${SRC_DEC}" ]]; then
  echo "${LOG_TAG} لم يتم العثور على أي ملف قرارات في ${OUT_DIR}"
  exit 1
fi

TS="$(date +%Y%m%d_%H%M%S)"
OUT_DEC="${OUT_DIR}/sf_suite_service_decisions_v2_${TS}.tsv"

echo "${LOG_TAG} استخدام ملف القرارات (مصدر): ${SRC_DEC}"
echo "${LOG_TAG} كتابة قرارات v2 في: ${OUT_DEC}"

awk -F'\t' -v OFS='\t' '
NR==1 {
  # ترويسة بدون تغيير
  print $0;
  next;
}

{
  fam = $1;
  unit = $2;
  kind = $3;
  role = $4;
  active_state = $5;
  sub_state = $6;
  main_pid = $7;
  ports = $8;
  fragment_path = $9;
  old_decision = $10;

  # الافتراضي: الاحتفاظ بالقرار القديم
  new_decision = old_decision;

  if (fam == "suite") {
    # خدمات السيوت الرسمية: نترك القرار كما هو (KEEP)
    print fam, unit, kind, role, active_state, sub_state, main_pid, ports, fragment_path, new_decision;
    next;
  }

  # أي family أخرى (legacy smartfrind-* حاليًا)
  # الافتراضي: DEPRECATE_LATER
  new_decision = "DEPRECATE_LATER";

  # مجموعة KEEP_BACKEND_ONLY
  if (unit ~ /^smartfrind-envwatch\.service$/ ||
      unit ~ /^smartfrind-envwatch\.timer$/  ||
      unit ~ /^smartfrind-runner\.service$/  ||
      unit ~ /^smartfrind-harvest\.service$/ ||
      unit ~ /^smartfrind-harvest\.timer$/   ||
      unit ~ /^smartfrind-ingest\.service$/  ||
      unit ~ /^smartfrind-ingest\.timer$/    ||
      unit ~ /^smartfrind-cma-sync\.service$/||
      unit ~ /^smartfrind-cma-sync\.timer$/  ||
      unit ~ /^smartfrind-raw-clean\.service$/ ||
      unit ~ /^smartfrind-raw-clean\.timer$/   ||
      unit ~ /^smartfrind-reflector\.service$/ ||
      unit ~ /^smartfrind-reflector\.timer$/   ||
      unit ~ /^smartfrind-learning\.service$/  ||
      unit ~ /^smartfrind-learning-agent\.service$/ ||
      unit ~ /^smartfrind-learning-agent\.timer$/   ||
      unit ~ /^smartfrind-autolearn\.service$/ ||
      unit ~ /^smartfrind-autolearn\.timer$/   ||
      unit ~ /^smartfrind-learner\.service$/   ||
      unit ~ /^smartfrind-learner\.timer$/     ||
      unit ~ /^smartfrind-backup\.timer$/) {
    new_decision = "KEEP_BACKEND_ONLY";
  }

  print fam, unit, kind, role, active_state, sub_state, main_pid, ports, fragment_path, new_decision;
}
' "${SRC_DEC}" > "${OUT_DEC}"

echo "${LOG_TAG} DONE. v2 decisions written to: ${OUT_DEC}"
