#!/usr/bin/env bash
set -euo pipefail

ROOT="/root/HyperFFactory"
IDENT_MD="$ROOT/docs/UNIFIED_FACTORY_LOGIN.md"
MOTD_SNIPPET="/etc/update-motd.d/99-hyperffactory-identity"

if [[ ! -f "$IDENT_MD" ]]; then
  echo "❌ ملف الهوية غير موجود: $IDENT_MD – شغّل أولاً: bin/hf_write_unified_login_md.sh"
  exit 1
fi

cat > "$MOTD_SNIPPET" <<'SNIP'
#!/usr/bin/env bash
ROOT="/root/HyperFFactory"
IDENT_MD="$ROOT/docs/UNIFIED_FACTORY_LOGIN.md"
PLAN_MD="$ROOT/plan_status.md"

echo "========================================================"
echo " HyperFFactory – Unified Factory Login (Server View)"
echo "========================================================"
echo "الجذر الموّحد      : $ROOT"
echo "ملف الهوية الرسمي : $IDENT_MD"
echo "ملف الملخص        : $PLAN_MD"
echo
echo "للاطلاع:"
echo "  cd $ROOT"
echo "  cat docs/UNIFIED_FACTORY_LOGIN.md"
echo "  cat plan_status.md"
echo
SNIP

chmod +x "$MOTD_SNIPPET"

echo "✅ تم تسجيل HyperFFactory في لوحة السيرفر (MOTD) بدون لمس السكربتات الأخرى."
