#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

OUT="/root/sf_reports/sf_suite_diag_live_$(date +%Y%m%d_%H%M%S).log"
mkdir -p /root/sf_reports

log(){ echo "$@" | tee -a "$OUT"; }

log "=== Live SmartFriend Suite Report (activating/failed) ==="
log "[وقت التقرير: $(date '+%F %T')]"
log

# جمع الوحدات في حالة activating/failed
mapfile -t PROBLEM_UNITS < <(
  systemctl list-units 'sf-*.service' 'smartfriend-*.service' 'smartfrind-*.service' \
    --state=activating,failed --no-legend 2>/dev/null | awk '{print $1}' | sort -u
)

if ((${#PROBLEM_UNITS[@]} == 0)); then
  log "لا توجد خدمات sf-*/smartfriend-*/smartfrind-* في حالة activating/failed حالياً."
  exit 0
fi

log "الخدمات التي تحت المراقبة:"
for u in "${PROBLEM_UNITS[@]}"; do
  log "  - $u"
done
log

for u in "${PROBLEM_UNITS[@]}"; do
  log "============================================================"
  log "### UNIT: $u"
  log "------------------------------------------------------------"
  log ">> systemctl status $u --no-pager -n 20"
  systemctl status "$u" --no-pager -n 20 2>&1 | tee -a "$OUT"

  log "------------------------------------------------------------"
  log ">> ExecStart / WorkingDirectory من تعريف الوحدة"
  systemctl cat "$u" 2>/dev/null | \
    awk '
      /^\[Service]/ {in_s=1; next}
      /^\[/ {in_s=0}
      in_s && /^ExecStart=/ {print "ExecStart=" $0; next}
      in_s && /^WorkingDirectory=/ {print "WorkingDirectory=" $0; next}
    ' | sed 's/^/    /' | tee -a "$OUT"

  # استخراج أول ExecStart (الأمر الرئيسي)
  exec_path="$(systemctl cat "$u" 2>/dev/null | awk -F= '
      /^ExecStart=/ {
        # بعد = ممكن يكون فيه خيارات، نأخذ أول توكن بعد =
        sub(/^ExecStart=/, "", $0);
        # إزالة المسافات الأولى
        gsub(/^[[:space:]]+/, "", $0);
        split($0, a, /[[:space:]]+/);
        print a[1];
        exit
      }
  ')"

  if [[ -n "${exec_path:-}" ]]; then
    # تصنيف حسب المسار (بدون لمس أي شيء)
    if [[ "$exec_path" == /opt/smartfriend-suite/* ]]; then
      log "CLASS=INSIDE_SUITE  EXEC=$exec_path"
    elif [[ "$exec_path" == /opt/ffactory/* || "$exec_path" == /srv/factory/* ]]; then
      log "CLASS=FFACTORY_OR_OLD  EXEC=$exec_path"
    else
      log "CLASS=OUTSIDE_SUITE  EXEC=$exec_path"
    fi
  else
    log "CLASS=UNKNOWN_EXEC  (لم يتم العثور على ExecStart واضح)"
  fi

  log
done

log "=== انتهى التقرير الحي ==="
