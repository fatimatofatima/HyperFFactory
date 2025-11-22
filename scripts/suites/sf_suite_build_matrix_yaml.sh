#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

LOG_TAG="[SF-MATRIX]"
OUT_DIR="/opt/smartfriend-suite/reports"
mkdir -p "$OUT_DIR"

echo "${LOG_TAG} البحث عن أحدث ملف قرارات v2..."
DEC_V2="$(ls -1 ${OUT_DIR}/sf_suite_service_decisions_v2_*.tsv 2>/dev/null | sort | tail -n 1 || true)"

if [[ -z "${DEC_V2}" ]] || [[ ! -f "${DEC_V2}" ]]; then
  echo "${LOG_TAG} لم يتم العثور على sf_suite_service_decisions_v2_*.tsv في ${OUT_DIR}"
  exit 1
fi

TS="$(date +%Y%m%d_%H%M%S)"
OUT_YAML="${OUT_DIR}/sf_suite_service_matrix_${TS}.yaml"

echo "${LOG_TAG} استخدام ملف القرارات: ${DEC_V2}"
echo "${LOG_TAG} كتابة Matrix إلى: ${OUT_YAML}"

{
  echo "# SmartFriend Suite – Service Matrix"
  echo "generated_at: \"$(date '+%F %T')\""
  echo "source_file: \"${DEC_V2}\""
  echo "note: \"Matrix مستخرجة من قرارات v2؛ لا يوجد أي تعديل على systemd أو ffactory\""
  echo "services:"
  awk -F'\t' '
    NR==1 { next }  # تخطي الترويسة
    {
      fam=$1; unit=$2; kind=$3; role=$4;
      active_state=$5; sub_state=$6;
      main_pid=$7; ports=$8; fragment_path=$9; decision=$10;

      printf "- family: '\''%s'\''\n", fam;
      printf "  unit: '\''%s'\''\n", unit;
      printf "  kind: '\''%s'\''\n", kind;
      printf "  role: '\''%s'\''\n", role;
      printf "  decision: '\''%s'\''\n", decision;
      printf "  active_state: '\''%s'\''\n", active_state;
      printf "  sub_state: '\''%s'\''\n", sub_state;
      printf "  main_pid: '\''%s'\''\n", main_pid;
      printf "  ports: '\''%s'\''\n", ports;
      printf "  fragment_path: '\''%s'\''\n", fragment_path;
      printf "\n";
    }
  ' "${DEC_V2}"
} > "${OUT_YAML}"

echo "${LOG_TAG} DONE. Matrix جاهزة:"
echo "${LOG_TAG}   ${OUT_YAML}"
