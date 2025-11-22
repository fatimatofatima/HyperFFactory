#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

log(){ echo "[$(date '+%F %T')] $*"; }

# خدمات تيليجرام المتعلقة بـ SmartFriend / SmartFrind / SmartFactory
SERVICES=(
  sf-smartfrind.service
  sf-smartfriend.service
  sf-smartfactory.service
  sf-telegram.service
  sf-telegram-audit.service
  sf-smartfrind.service
  sf-smartfactory.service
  smartfrind-bot.service
)

log "1) عرض حالة خدمات تيليجرام..."
for s in "${SERVICES[@]}"; do
  if systemctl list-unit-files "$s" &>/dev/null; then
    active_state="$(systemctl is-active "$s" 2>/dev/null || true)"
    failed_state="$(systemctl is-failed "$s" 2>/dev/null || true)"
    log "   - $s :: active=$active_state failed=$failed_state"
  else
    log "   - $s غير موجودة (تجاهل)"
  fi
done

log "2) إيقاف جميع خدمات تيليجرام لتجميد الوضع ومنع الـ restart-loop..."
for s in "${SERVICES[@]}"; do
  if systemctl list-unit-files "$s" &>/dev/null; then
    systemctl stop "$s" 2>/dev/null || true
  fi
done

log "3) البحث عن ملفات البيئة التي تحتوي على مفاتيح توكن تيليجرام..."
SEARCH_ROOTS=(
  /opt/smartfriend-suite
  /opt/smartfrind
  /etc/systemd/system
  /etc/default
)

# أسماء المتغيرات الشائعة لمفاتيح البوت
KEYS_REGEX='TG_BOT_TOKEN|TELEGRAM_BOT_TOKEN|BOT_TOKEN|SMARTFRIND_TG_BOT_TOKEN|SMARTFACTORY_TG_BOT_TOKEN|AUDIT_TG_BOT_TOKEN'

FOUND_FILES=()

for root in "${SEARCH_ROOTS[@]}"; do
  [ -d "$root" ] || continue
  log "   - فحص المجلد: $root"
  # نفحص env + service + sh + py للحصول على كل أماكن تعريف التوكن
  while IFS= read -r -d '' f; do
    if grep -Eq "$KEYS_REGEX" "$f"; then
      FOUND_FILES+=( "$f" )
    fi
  done < <(find "$root" -maxdepth 6 -type f \( -name '*.env' -o -name '*.service' -o -name '*.sh' -o -name '*.py' \) -print0 2>/dev/null)
done

if [ "${#FOUND_FILES[@]}" -eq 0 ]; then
  log "⚠ لم أجد أي ملفات تحتوي مفاتيح توكن في المسارات المتوقعة."
else
  log "4) الملفات التي تحتوي على مفاتيح التوكن (القيم مُخفاة، عدّلها يدويًا):"
  printf '%s\n' "${FOUND_FILES[@]}" | sort -u | while read -r file; do
    echo "──────────────── $file"
    # إظهار الأسطر مع إخفاء قيمة التوكن
    grep -En "$KEYS_REGEX" "$file" | sed -E 's/(=).*/\1********/g' || true
  done
fi

log "5) ملاحظة خاصة بخطأ local في /root/sf_bots_and_ask_doctor.sh:"
log "   - السكربت /root/sf_bots_and_ask_doctor.sh يستخدم local خارج دالة (line 161)."
log "   - الإصلاح الآمن: افتح الملف وعدّل السطر 161 يدويًا بحذف كلمة local أو نقل التعريف داخل function."
log "     مثال يدوي (لا يُنفذ تلقائيًا هنا):"
log "       nano /root/sf_bots_and_ask_doctor.sh   # ثم عدّل السطر 161"

log "6) بعد تعديل التوكنات يدويًا في الملفات أعلاه باستخدام توكنات صحيحة من BotFather:"
log "   يمكنك إعادة تشغيل الخدمات بالأمر التالي:"
echo
echo "    systemctl restart sf-smartfrind.service sf-smartfriend.service sf-smartfactory.service sf-telegram.service sf-telegram-audit.service smartfrind-bot.service"
echo
log "انتهى سكربت الفحص/الإصلاح للجزء الخاص بتوكنات تيليجرام."
