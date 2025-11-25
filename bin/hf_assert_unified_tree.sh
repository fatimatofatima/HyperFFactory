#!/usr/bin/env bash
# HyperFFactory – Unified Tree Assertion
# - يفرض سياسة الهيكل الموحد:
#   * ROOT ثابت داخل /root/HyperFFactory (أو حسب ما يمرَّر)
#   * وجود مجلد داخلي opt/ تحت ROOT
#   * منع symlink/hardlink للهروب خارج ROOT
#   * استثناء وحيد للتكامل: /opt/smartfriend-suite , /opt/ffactory
# - يسجّل النتائج في reports/ (لا يغيّر قواعد البيانات)

set -euo pipefail

#-------------------------------
# 0) Parsing arguments (ROOT + --fix)
#-------------------------------
FIX_MODE=0
ROOT=""

for arg in "$@"; do
  case "$arg" in
    --fix|-f)
      FIX_MODE=1
      ;;
    *)
      if [[ -z "${ROOT}" ]]; then
        ROOT="${arg}"
      else
        echo "WARN: تم تجاهل وسيط إضافي غير معروف: ${arg}" >&2
      fi
      ;;
  esac
done

if [[ -z "${ROOT}" ]]; then
  ROOT="/root/HyperFFactory"
fi

# إزالة / الزائدة إن وُجدت
ROOT="${ROOT%/}"

if [[ -z "${ROOT}" || "${ROOT}" == "/" ]]; then
  echo "❌ ROOT غير صالح: '${ROOT}'" >&2
  exit 1
fi

#-------------------------------
# 1) إعداد التقارير
#-------------------------------
REPORTS_DIR="${ROOT}/reports"
mkdir -p "${REPORTS_DIR}"

RUN_ID="$(date '+%Y%m%d_%H%M%S')"
REPORT_FILE="${REPORTS_DIR}/hf_assert_unified_tree_${RUN_ID}.log"
LATEST_FILE="${REPORTS_DIR}/hf_assert_unified_tree_latest.log"

log() {
  local msg="$*"
  local ts
  ts="$(date '+%Y-%m-%dT%H:%M:%S%z')"
  printf '%s %s\n' "${ts}" "${msg}" | tee -a "${REPORT_FILE}" >/dev/null
}

log "=================================================="
log " HyperFFactory – Unified Tree Assertion"
log " ROOT : ${ROOT}"
log " MODE : $([[ ${FIX_MODE} -eq 1 ]] && echo 'CHECK+FIX' || echo 'CHECK-ONLY')"
log " TIME : $(date '+%Y-%m-%d %H:%M:%S %z')"
log "=================================================="

if [[ ! -d "${ROOT}" ]]; then
  log "❌ ROOT غير موجود على القرص: ${ROOT}"
  cp "${REPORT_FILE}" "${LATEST_FILE}" 2>/dev/null || true
  exit 1
fi

#-------------------------------
# 2) ضمان وجود opt/ الداخلي
#-------------------------------
INTERNAL_OPT="${ROOT}/opt"
if [[ -d "${INTERNAL_OPT}" ]]; then
  log "CHECK OK: internal opt/ exists at ${INTERNAL_OPT}"
else
  if [[ ${FIX_MODE} -eq 1 ]]; then
    mkdir -p "${INTERNAL_OPT}"
    log "FIX CREATED: internal opt/ directory at ${INTERNAL_OPT}"
  else
    log "WARN: internal opt/ directory مفقود عند ${INTERNAL_OPT} (سيتم إنشاؤه عند تشغيل --fix)"
  fi
fi

#-------------------------------
# 3) فحص Symlinks (Escape Pointers)
#-------------------------------
internal_ok=0
allowed_external=0
escape_pointers=0
broken_symlinks=0

log "--------------------------------------------------"
log "[SYMLINK SCAN] فحص الروابط داخل ROOT"
log "--------------------------------------------------"

# نتجنّب .git لتقليل الضوضاء
while IFS= read -r -d '' link; do
  # مسار كامل للـ symlink
  link_path="${link}"

  # محاولة معرفة الهدف الحقيقي (قد يفشل إن كان مكسور)
  target="$(readlink -f "${link_path}" 2>/dev/null || true)"

  if [[ -z "${target}" ]]; then
    ((broken_symlinks++))
    ((escape_pointers++))
    log "ESCAPE_POINTER (BROKEN): ${link_path} -> (BROKEN)"
    if [[ ${FIX_MODE} -eq 1 ]]; then
      rm -f "${link_path}"
      log "FIXED: removed broken escape symlink ${link_path}"
    fi
    continue
  fi

  # داخلي بالكامل داخل ROOT
  if [[ "${target}" == "${ROOT}"* ]]; then
    ((internal_ok++))
    # لا نطبع كل شيء بالتفصيل لتقليل الضوضاء
    continue
  fi

  # تكامل مسموح به مع /opt/smartfriend-suite أو /opt/ffactory
  if [[ "${target}" == /opt/smartfriend-suite* || "${target}" == /opt/ffactory* ]]; then
    ((allowed_external++))
    log "ALLOWED INTEGRATION SYMLINK: ${link_path} -> ${target}"
    continue
  fi

  # أي شيء آخر = Escape Pointer
  ((escape_pointers++))
  log "ESCAPE_POINTER: ${link_path} -> ${target}"

  if [[ ${FIX_MODE} -eq 1 ]]; then
    rm -f "${link_path}"
    log "FIXED: removed escape symlink ${link_path}"
  fi

done < <(find "${ROOT}" \
            -path "${ROOT}/.git" -prune -o \
            -type l -print0 2>/dev/null)

log "--------------------------------------------------"
log "SYMLINK SUMMARY:"
log "  INTERNAL_OK        : ${internal_ok}"
log "  ALLOWED_EXTERNAL   : ${allowed_external} (smartfriend-suite / ffactory فقط)"
log "  ESCAPE_POINTERS    : ${escape_pointers}"
log "  BROKEN_SYMLINKS    : ${broken_symlinks}"
log "--------------------------------------------------"

#-------------------------------
# 4) فحص Hardlinks (multi-link files)
#-------------------------------
log "[HARDLINK SCAN] فحص ملفات ذات link count>1 تحت ROOT"
hardlink_files=()
while IFS= read -r -d '' f; do
  hardlink_files+=("${f}")
done < <(find "${ROOT}" -xdev -type f -links +1 -print0 2>/dev/null || true)

if ((${#hardlink_files[@]} > 0)); then
  log "WARN HARDLINKS: تم العثور على ${#hardlink_files[@]} ملف/ملفات link count>1 (قد تشير لبيانات مشتركة خارج ROOT):"
  for f in "${hardlink_files[@]}"; do
    stat_info="$(stat -c '%h %i %n' "${f}" 2>/dev/null || echo "?? ?? ${f}")"
    log "  HARDLINK: ${stat_info}"
  done
else
  log "CHECK OK: لم يتم العثور على ملفات ذات link count>1 تحت ROOT."
fi

#-------------------------------
# 5) النتيجة النهائية والتخزين
#-------------------------------
if (( escape_pointers > 0 )); then
  if [[ ${FIX_MODE} -eq 1 ]]; then
    log "RESULT: POLICY VIOLATION كانت موجودة وتمت محاولة الإصلاح (escape_pointers=${escape_pointers_before_fix:-${escape_pointers}})."
  else
    log "RESULT: POLICY VIOLATION – تم رصد Escape Pointers (escape_pointers=${escape_pointers})."
  fi
else
  log "RESULT: POLICY OK – لا توجد Escape Pointers مرصودة."
fi

log "=================================================="
log " نهاية فحص hf_assert_unified_tree"
log " تقرير مفصّل في: ${REPORT_FILE}"
log "=================================================="

# تحديث آخر تقرير
cp "${REPORT_FILE}" "${LATEST_FILE}" 2>/dev/null || true

exit 0
