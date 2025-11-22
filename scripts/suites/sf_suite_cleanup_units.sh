#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

DRY_RUN="${DRY_RUN:-1}"

ARCHIVE_BASE="/opt/smartfriend-suite/legacy_units/systemd"
mkdir -p "$ARCHIVE_BASE"

REPORT_DIR="/opt/smartfriend-suite/reports"
mkdir -p "$REPORT_DIR"

TS="$(date '+%Y%m%d_%H%M%S')"
REPORT="$REPORT_DIR/sf_suite_cleanup_units_${TS}.log"

log(){ echo "[$(date '+%F %T')] $*"; }

collect_units() {
  systemctl list-unit-files "smartfrind-*" --no-legend 2>/dev/null | awk '{print $1}' || true
}

cleanup_unit() {
  local u="$1"
  [[ -z "$u" ]] && return 0

  local frag
  frag="$(systemctl show -p FragmentPath "$u" 2>/dev/null | sed 's/^FragmentPath=//')"

  if [[ -z "$frag" || "$frag" == "-" ]]; then
    log "Unit $u لا يحتوي FragmentPath صالح (ربما generated أو not-found)، تخطي." | tee -a "$REPORT"
    return 0
  fi

  if [[ "$frag" != /etc/systemd/system/* ]]; then
    log "Unit $u FragmentPath=$frag خارج /etc/systemd/system – لن نلمسه (حماية النظام)." | tee -a "$REPORT"
    return 0
  fi

  local base
  base="$(basename "$frag")"
  local target="$ARCHIVE_BASE/$base"

  if [[ "$DRY_RUN" == "1" ]]; then
    log "DRY-RUN would: mv '$frag' '$target'" | tee -a "$REPORT"
  else
    if [[ -f "$frag" ]]; then
      log "Archiving unit file: $frag -> $target" | tee -a "$REPORT"
      mkdir -p "$ARCHIVE_BASE"
      mv "$frag" "$target"
    else
      log "تحذير: $frag غير موجود فعلياً، تخطي." | tee -a "$REPORT"
    fi
  fi
}

main() {
  {
    echo "============================================================"
    echo " SmartFriend Suite – Cleanup smartfrind-* systemd units"
    echo " Timestamp : $(date '+%F %T')"
    echo " Hostname  : $(hostname)"
    echo " DRY_RUN   : $DRY_RUN (1=log فقط، 0=نقل فعلي إلى الأرشيف)"
    echo " Archive   : $ARCHIVE_BASE"
    echo "============================================================"
    echo
    echo "1) قائمة وحدات smartfrind-* قبل التنظيف"
    echo "------------------------------------------------------------"
  } | tee "$REPORT"

  log "Unit files smartfrind-*:" | tee -a "$REPORT"
  systemctl list-unit-files "smartfrind-*" --no-legend 2>/dev/null | tee -a "$REPORT" || true

  echo >> "$REPORT"
  echo "------------------------------------------------------------" | tee -a "$REPORT"
  echo "2) أرشفة ملفات الوحدات من /etc/systemd/system إلى $ARCHIVE_BASE" | tee -a "$REPORT"
  echo "------------------------------------------------------------" | tee -a "$REPORT"

  mapfile -t UNITS < <(collect_units | sort -u)

  if [[ "${#UNITS[@]}" -eq 0 ]]; then
    log "لا توجد وحدات smartfrind-* مُسجلة." | tee -a "$REPORT"
  else
    for u in "${UNITS[@]}"; do
      cleanup_unit "$u"
    done
  fi

  echo >> "$REPORT"
  echo "------------------------------------------------------------" | tee -a "$REPORT"
  echo "3) daemon-reload (في الوضع الفعلي فقط)" | tee -a "$REPORT"
  echo "------------------------------------------------------------" | tee -a "$REPORT"

  if [[ "$DRY_RUN" == "1" ]]; then
    log "DRY-RUN: لن يتم تنفيذ systemctl daemon-reload." | tee -a "$REPORT"
  else
    log "Running: systemctl daemon-reload" | tee -a "$REPORT"
    systemctl daemon-reload 2>&1 | tee -a "$REPORT" || true
  fi

  echo >> "$REPORT"
  log "Cleanup finished. Report: $REPORT" | tee -a "$REPORT"
}

main
