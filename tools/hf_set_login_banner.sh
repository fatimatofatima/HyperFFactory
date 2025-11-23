#!/usr/bin/env bash
# HyperFFactory - تعيين لوحة تسجيل الدخول من README بدلاً من لوحة Contabo

set -euo pipefail

ROOT="/root/HyperFFactory"
BANNER_FILE="${ROOT}/README.md"

if [ ! -f "$BANNER_FILE" ]; then
  echo "❌ ملف البانر غير موجود: $BANNER_FILE"
  exit 1
fi

TS="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="${ROOT}/motd_backup_${TS}"
mkdir -p "${BACKUP_DIR}"

echo "📦 أخذ نسخة احتياطية من MOTD إلى: ${BACKUP_DIR}"

# نسخ motd القديم وسكربتات update-motd.d (خفيفة)
cp -a /etc/motd "${BACKUP_DIR}/motd.orig" 2>/dev/null || true
cp -a /etc/update-motd.d "${BACKUP_DIR}/update-motd.d.orig" 2>/dev/null || true

echo "🔕 البحث عن سكربتات تحتوي على Contabo وتعطيلها (chmod -x)..."
if [ -d /etc/update-motd.d ]; then
  for f in /etc/update-motd.d/*; do
    [ -f "$f" ] || continue
    if grep -qi "contabo" "$f" 2>/dev/null; then
      echo "   ➜ تعطيل: $f"
      chmod -x "$f" || true
    fi
  done
fi

echo "🛠️ إنشاء /etc/update-motd.d/99-hyper-ffactory ..."

cat > /etc/update-motd.d/99-hyper-ffactory <<'INNER_EOF'
#!/usr/bin/env bash
# MOTD مخصص لعرض لوحة HyperFFactory من README

echo ""
echo "========================================================"
echo "        HyperFFactory – Unified Factory Login"
echo "========================================================"
echo ""

if [ -f "/root/HyperFFactory/README.md" ]; then
  cat "/root/HyperFFactory/README.md"
else
  echo "⚠️ لا يمكن قراءة /root/HyperFFactory/README.md"
fi

echo ""
INNER_EOF

chmod +x /etc/update-motd.d/99-hyper-ffactory

echo "✅ تم ضبط لوحة تسجيل الدخول لعرض: ${BANNER_FILE}"
echo "📁 النسخة الاحتياطية في: ${BACKUP_DIR}"
echo "ℹ️ يمكنك معاينة الناتج الآن بالأمر:"
echo "   run-parts /etc/update-motd.d"
