#!/usr/bin/env bash
# HyperFFactory – Unified Factory Login
# - نقطة الدخول الرسمية للمصنع الموحّد.
# - يطبّق:
#   1) فحص بوليسي الهيكل الموحّد (Unified Tree Policy)
#   2) تشغيل دورة أنظمة 8.x (Tasks / Quality / Experience / Errors)
#   3) عرض Snapshot + Dashboard مختصر

set -euo pipefail

ROOT="${ROOT:-/root/HyperFFactory}"

cd "$ROOT"

cat <<'HDR'
========================================================
        HyperFFactory – Unified Factory Login
========================================================
HDR

ts() {
  date +"%Y-%m-%d %H:%M:%S %z"
}

log() {
  local level="$1"; shift
  echo "$(ts) [LOGIN] [$level] $*"
}

log INFO "ROOT = $ROOT"

# 1) فحص بوليسي الهيكل الموحّد
if [[ -x bin/hf_assert_unified_tree.sh ]]; then
  log INFO "تشغيل hf_assert_unified_tree.sh (Unified Tree Policy)..."
  if bin/hf_assert_unified_tree.sh; then
    log INFO "Unified Tree Policy ✅"
  else
    log WARN "Unified Tree Policy ❌ – راجع التقارير في reports/ و db/meta/."
  fi
else
  log WARN "bin/hf_assert_unified_tree.sh غير موجود أو غير قابل للتنفيذ."
fi

# 2) دورة أنظمة 8.x (Tasks / Quality / Experience / Errors)
if [[ -x tools/hf_meta_8x_full_run.sh ]]; then
  log INFO "تشغيل دورة أنظمة 8.x عبر tools/hf_meta_8x_full_run.sh..."
  bash tools/hf_meta_8x_full_run.sh
else
  log WARN "tools/hf_meta_8x_full_run.sh غير موجود – أنشئه ثم أعد تشغيل hf_login."
fi

log INFO "HyperFFactory Login flow انتهى."
