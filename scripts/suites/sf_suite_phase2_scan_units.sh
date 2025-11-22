#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

SUITE_BASE="/opt/smartfriend-suite"
OUT="/root/sf_reports/sf_suite_phase2_scan_units_$(date +%Y%m%d_%H%M%S).log"
mkdir -p /root/sf_reports

log(){ echo "$@" | tee -a "$OUT"; }

log "=== Phase 2 – Scan SmartFriend Suite Units (sf-*, smartfriend-*) ==="
log "[وقت التقرير: $(date '+%F %T')]"
log "SUITE_BASE = $SUITE_BASE"
log

# جمع كل الوحدات المستهدفة
mapfile -t UNITS < <(
  systemctl list-unit-files 'sf-*.service' 'smartfriend-*.service' \
    --no-legend 2>/dev/null | awk '{print $1}' | sort -u
)

if ((${#UNITS[@]} == 0)); then
  log "لا توجد وحدات sf-*/smartfriend-* مسجلة في systemd."
  exit 0
fi

INSIDE_CNT=0
OUTSIDE_CNT=0
BROKEN_CNT=0
SYMLINK_OUT_CNT=0

for u in "${UNITS[@]}"; do
  log "------------------------------------------------------------"
  log "### UNIT: $u"

  # مسار ملف الوحدة
  FRAG_LINE="$(systemctl show -p FragmentPath "$u" 2>/dev/null || true)"
  UNIT_FILE="${FRAG_LINE#FragmentPath=}"

  if [[ -z "$UNIT_FILE" || ! -f "$UNIT_FILE" ]]; then
    log "  [!] لا يمكن تحديد ملف الوحدة (FragmentPath) أو الملف غير موجود."
    continue
  fi

  log "  [i] وحدة systemd: $UNIT_FILE"

  # استخراج أسطر ExecStart من ملف الوحدة
  mapfile -t EXECLINES < <(grep -E '^ExecStart=' "$UNIT_FILE" 2>/dev/null || true)

  if ((${#EXECLINES[@]} == 0)); then
    log "  [!] لا توجد أسطر ExecStart في هذه الوحدة."
    continue
  fi

  for line in "${EXECLINES[@]}"; do
    # إزالة ExecStart= وأخذ أول توكن كأمر فعلي
    CMD="${line#ExecStart=}"
    # ممكن يكون فيها خيارات قبل الأمر، نأخذ أول توكن غير فارغ
    EXE="$(echo "$CMD" | awk '{print $1}')"

    if [[ -z "$EXE" ]]; then
      log "  [!] ExecStart بدون أمر واضح: $line"
      ((BROKEN_CNT++))
      continue
    fi

    # لو ExecStart= مثبت بـ '-' (ignore failure)، نشيله في التحليل
    if [[ "$EXE" == -* ]]; then
      EXE="${EXE#-}"
    fi

    REAL="$EXE"
    if [[ -e "$EXE" || -L "$EXE" ]]; then
      REAL="$(readlink -f "$EXE" 2>/dev/null || echo "$EXE")"
    fi

    CLASS="UNKNOWN"

    if [[ ! -e "$EXE" && ! -L "$EXE" ]]; then
      CLASS="BROKEN_PATH"
      ((BROKEN_CNT++))
    elif [[ "$REAL" == "$SUITE_BASE"* ]]; then
      CLASS="INSIDE_SUITE"
      ((INSIDE_CNT++))
    else
      # خارج السويت
      ((OUTSIDE_CNT++))
      if [[ -L "$EXE" && "$REAL" != "$SUITE_BASE"* ]]; then
        CLASS="SYMLINK_OUTSIDE"
        ((SYMLINK_OUT_CNT++))
      else
        CLASS="OUTSIDE_SUITE"
      fi
    fi

    log "  - ExecStart line: $line"
    log "    → EXE:   $EXE"
    log "    → REAL:  $REAL"
    log "    → CLASS: $CLASS"

    # تصنيف إضافي حسب البادئة لمعرفه علاقته بـ ffactory أو smartfrind
    if [[ "$REAL" == /srv/factory/* || "$REAL" == /opt/ffactory/* || "$REAL" == /srv/ffactory/* ]]; then
      log "    → TAG: FFATORY_RELATED"
    elif [[ "$REAL" == /opt/smartfrind/* ]]; then
      log "    → TAG: OLDSMARTFRIND_RELATED"
    fi
  done
done

log
log "=== Summary ==="
log "  * داخل السويت فعليًا (INSIDE_SUITE):   $INSIDE_CNT"
log "  * خارج السويت (OUTSIDE_SUITE):         $OUTSIDE_CNT"
log "  * مسارات مكسورة (BROKEN_PATH):        $BROKEN_CNT"
log "  * Symlink برّه السويت (SYMLINK_OUTSIDE): $SYMLINK_OUT_CNT"
log
log "تقرير مفصل محفوظ في: $OUT"
