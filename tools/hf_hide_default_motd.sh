#!/usr/bin/env bash
# HyperFFactory - إخفاء سكربتات MOTD الافتراضية وترك 99-hyper-ffactory فقط

set -euo pipefail

ROOT="/root/HyperFFactory"
TS="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="${ROOT}/motd_backup_hide_default_${TS}"
mkdir -p "${BACKUP_DIR}"

if [ -d /etc/update-motd.d ]; then
  echo "📦 أخذ نسخة احتياطية كاملة من /etc/update-motd.d إلى: ${BACKUP_DIR}"
  cp -a /etc/update-motd.d "${BACKUP_DIR}/update-motd.d.full" 2>/dev/null || true

  echo "🔕 تعطيل كل سكربتات MOTD الافتراضية ماعدا 99-hyper-ffactory..."
  for f in /etc/update-motd.d/*; do
    [ -f "$f" ] || continue
    base="$(basename "$f")"
    if [ "$base" != "99-hyper-ffactory" ]; then
      echo "   ➜ تعطيل: $f"
      chmod -x "$f" || true
    fi
  done
else
  echo "⚠️ مجلد /etc/update-motd.d غير موجود"
fi

echo "✅ تم إخفاء لوحة Ubuntu الافتراضية والإبقاء على HyperFFactory فقط"
echo "📁 النسخة الاحتياطية في: ${BACKUP_DIR}"
echo "ℹ️ يمكنك معاينة الناتج الآن بالأمر:"
echo "   run-parts /etc/update-motd.d"
