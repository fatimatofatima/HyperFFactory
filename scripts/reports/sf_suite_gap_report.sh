#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date '+%Y%m%d_%H%M%S')"
BASE_DIR="/opt/smartfriend-suite"
REPORT_DIR="$BASE_DIR/reports"
GAP_FILE="$REPORT_DIR/sf_suite_gap_report_${TS}.txt"

mkdir -p "$REPORT_DIR"

section() {
  echo
  echo "------------------------------------------------------------"
  echo "$1"
  echo "------------------------------------------------------------"
}

summarize_family() {
  local fam="$1"
  echo "• عائلة ${fam}-*"
  systemctl list-unit-files "${fam}-*" --no-legend 2>/dev/null | awk '
    {files++}
    END{
      if(files=="") files=0;
      printf("  - عدد unit files: %d\n", files);
    }'
  systemctl list-units "${fam}-*" --no-legend --plain 2>/dev/null | awk '
    {units++; state[$4]++}
    END{
      if(units=="") units=0;
      printf("  - عدد الوحدات المحملة: %d\n", units);
      for(s in state) printf("    * %s: %d\n", s, state[s]);
    }'
}

{
  echo "============================================================"
  echo " SmartFriend Suite – Gap Report (sf / smartfriend / smartfrind)"
  echo " Timestamp : $(date '+%F %T')"
  echo " Hostname  : $(hostname)"
  echo "============================================================"

  section "1) ملخص حسب العائلة"
  summarize_family "sf"
  summarize_family "smartfriend"
  summarize_family "smartfrind"

  section "2) وحدات Legacy (smartfrind-*) ما زالت نشطة"
  if systemctl list-units 'smartfrind-*' --no-legend --plain 2>/dev/null | grep -q '.'; then
    systemctl list-units 'smartfrind-*' --no-legend --plain 2>/dev/null \
      | awk '{printf("  - %s\t[%s]\t%s\n",$1,$4,$5)}'
  else
    echo "  (لا توجد وحدات smartfrind-* نشطة حالياً)"
  fi

  section "3) خدمات SmartFriend Suite الحرجة من sf-* (Core / Gateway / Memory / Web / Spider / Health / Brain)"
  critical_sf=$(
    systemctl list-unit-files 'sf-*' --no-legend 2>/dev/null | awk '{print $1}' | \
      grep -E 'sf-(core|unified|memory|web|spider|health|ingest|kb|learn)' || true
  )
  if [ -z "$critical_sf" ]; then
    echo "  (لا توجد خدمات sf-* حرجة مطابقة للنمط المحدد)"
  else
    while read -r u; do
      [ -z "$u" ] && continue
      act="$(systemctl is-active "$u" 2>/dev/null || echo unknown)"
      en="$(systemctl is-enabled "$u" 2>/dev/null || echo unknown)"
      desc="$(systemctl show "$u" -p Description 2>/dev/null | sed 's/^Description=//')"
      printf "  - %-32s  active=%-10s enabled=%-8s  %s\n" "$u" "$act" "$en" "$desc"
    done <<< "$critical_sf"
  fi

  section "4) Bots عبر العائلات (sf-*, smartfriend-*, smartfrind-*)"
  for fam in sf smartfriend smartfrind; do
    echo "• Bots من عائلة ${fam}-*:"
    bots=$(
      systemctl list-unit-files "${fam}-*" --no-legend 2>/dev/null | awk '{print $1}' | \
        grep -Ei 'bot|telegram' || true
    )
    if [ -z "$bots" ]; then
      echo "  (لا يوجد bots في هذه العائلة)"
    else
      while read -r b; do
        [ -z "$b" ] && continue
        act="$(systemctl is-active "$b" 2>/dev/null || echo unknown)"
        en="$(systemctl is-enabled "$b" 2>/dev/null || echo unknown)"
        desc="$(systemctl show "$b" -p Description 2>/dev/null | sed 's/^Description=//')"
        printf "  - %-32s  active=%-10s enabled=%-8s  %s\n" "$b" "$act" "$en" "$desc"
      done <<< "$bots"
    fi
    echo
  done

  section "5) تغطية البورتات الحالية (80, 821x, 82xx)"
  if command -v ss >/dev/null 2>&1; then
    ss -tulpn 2>/dev/null | grep -E '(:80|:821[0-9]|:82[0-9]{2})' || echo "  (لا توجد بورتات مطابقة)"
  else
    echo "  (أداة ss غير متوفرة)"
  fi

  section "6) خريطة استرشادية للفجوات G1..G10"
  echo "G1 – ازدواجية البراند والخدمات:"
  echo "  • وجود وحدات smartfrind-* نشطة في قسم (2) ⇒ لازم تتجمّد لاحقاً وننقل منطقها إلى sf-*."
  echo
  echo "G2 – ملكية البورتات الأساسية (8210 / 8211 / 8220):"
  echo "  • من قسم (5): أي process على هذه البورتات ليس من مسار sf-* ⇒ يحتاج نقل أو إعادة توجيه."
  echo
  echo "G3 – Memory API:"
  echo "  • من قسم (3): إذا sf-memory.service inactive/failed أو غير موجود ⇒ Memory API غير جاهز."
  echo
  echo "G4 – Web UI:"
  echo "  • من قسم (3) + قسم (5): إذا sf-web.service failed أو لا يوجد LISTEN على 8390 ⇒ فجوة في لوحة السيوت."
  echo
  echo "G5 – Brain / Learning:"
  echo "  • sf-ingest / sf-kb-build / sf-learn / sf-learning مقابل أي smartfrind-harvest/ingest نشط ⇒ نظامان لنفس الدور."
  echo
  echo "G6 – Spider / Harvester:"
  echo "  • sf-spider.* مقابل smartfrind-harvest.* ⇒ Spider الرسمي لازم يكون من sf-* فقط لاحقاً."
  echo
  echo "G7 – Bots:"
  echo "  • من قسم (4): تكرار أدوار البوت بين sf-* و smartfrind-* ⇒ سنختار لاحقاً Bot رسمي واحد لكل دور."
  echo
  echo "G8 – Health / Guard:"
  echo "  • حالة sf-health.service + أي smartfrind-* watchdog/guardian نشط ⇒ نحتاج Health موحّد من sf-*."
  echo
  echo "G9 – Secrets / ENV:"
  echo "  • أي خدمة sf-* حرجة في قسم (3) حالتها failed ⇒ نرجع لـ journalctl لهذه الخدمة (غالباً توكن/ENV)."
  echo
  echo "G10 – وحدات systemd القديمة:"
  echo "  • أي smartfrind-* في قسم (2) حالة failed/inactive مع unit file موجود ⇒ مرشح للأرشفة بدون حذف بيانات."
  echo
  echo "ملحوظة: هذا السكربت لا يغيّر أي خدمة؛ قراءة وتحليل فقط."

} | tee "$GAP_FILE"

echo
echo "[INFO] تم إنشاء تقرير النواقص:"
echo "       $GAP_FILE"
