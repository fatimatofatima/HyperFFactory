#!/usr/bin/env bash
set -euo pipefail

ROOT="/root/HyperFFactory"
README="$ROOT/README.md"
PLAN="$ROOT/plan_status.md"
IDENT="$ROOT/docs/UNIFIED_FACTORY_LOGIN.md"

errors=0
warns=0

section() {
  echo
  echo "--------------------------------------------------"
  echo "🔍 $1"
  echo "--------------------------------------------------"
}

ok()   { echo "✅ $1"; }
warn() { echo "⚠️  $1"; warns=$((warns+1)); }
err()  { echo "❌ $1"; errors=$((errors+1)); }

# 0) تأكيد الجذر
section "التحقق من الجذر والملفات الأساسية"

if [[ "$(pwd)" != "$ROOT" ]]; then
  warn "التنفيذ من $(pwd) وليس من $ROOT – يفضّل التشغيل من الجذر الرسمي."
fi

if [[ ! -d "$ROOT" ]]; then
  err "الجذر $ROOT غير موجود – هذا يخالف تعريف المصنع الموحّد."
  echo
  echo "❌ VERIFIED: فشل أساسي في وجود الجذر."
  exit 1
fi
ok "الجذر $ROOT موجود."

[[ -f "$README" ]] || err "ملف README.md غير موجود في $README."
[[ -f "$PLAN"   ]] || err "ملف plan_status.md غير موجود في $PLAN."
[[ -f "$IDENT"  ]] || err "ملف الهوية docs/UNIFIED_FACTORY_LOGIN.md غير موجود في $IDENT."

if [[ -f "$README" && -f "$PLAN" && -f "$IDENT" ]]; then
  ok "ملفات الهوية والخطة والملخص موجودة."
fi

# 1) التحقق من الهيكل الموحّد ووجود opt الداخلي
section "التحقق من الهيكل الموحّد وopt الداخلي"

if [[ -d "$ROOT/opt" ]]; then
  ok "مجلد opt الداخلي موجود: $ROOT/opt (جزء من الهيكل الموحّد)."
else
  err "مجلد opt الداخلي غير موجود تحت $ROOT – مخالف لسياسة الشجرة الموحّدة."
fi

if [[ -d "/opt/smartfriend-suite" ]]; then
  ok "مجلد /opt/smartfriend-suite موجود (نقطة تكامل رسمية)."
else
  warn "لم يتم العثور على /opt/smartfriend-suite – تحقق يدويًا من السيوت."
fi

if [[ -d "/opt/ffactory" ]]; then
  ok "مجلد /opt/ffactory موجود (Stack خارجي متكامل)."
else
  warn "لم يتم العثور على /opt/ffactory – تحقق يدويًا من Stack ffactory."
fi

# 2) التحقق من وجود نص سياسة الهيكل الموحّد وتسجيل التقدّم
section "التحقق من توثيق السياسة (الهيكل الموحّد + تسجيل التقدّم)"

check_phrase() {
  local file="$1"
  local phrase="$2"
  local label="$3"
  if [[ ! -f "$file" ]]; then
    err "لا يمكن فحص $label – الملف غير موجود: $file"
    return
  fi
  if grep -q "$phrase" "$file"; then
    ok "العبارة '$phrase' موجودة في $label."
  else
    err "العبارة '$phrase' مفقودة من $label – قد يكون التوثيق غير مكتمل."
  fi
}

# سياسة الهيكل الموحّد الصارمة
check_phrase "$README" "سياسة الهيكل الموحّد الصارمة" "README.md"
check_phrase "$IDENT"  "سياسة الهيكل الموحّد الصارمة" "UNIFIED_FACTORY_LOGIN.md"

# إلزام تسجيل التقدّم
check_phrase "$README" "إلزام تسجيل التقدّم" "README.md"
check_phrase "$IDENT"  "إلزام تسجيل التقدّم" "UNIFIED_FACTORY_LOGIN.md"

# ضرورة تسجيل التقدّم في plan_status
check_phrase "$PLAN" "ضرورة تسجيل التقدّم والملفات والمسارات واقتراح الحالة الحالية في الخطة" "plan_status.md"

# 3) فحص سكربت فحص الشجرة hf_assert_unified_tree.sh
section "التحقق من سكربت فحص الشجرة الموحّدة"

ASSERT_SCRIPT="$ROOT/bin/hf_assert_unified_tree.sh"
if [[ -x "$ASSERT_SCRIPT" ]]; then
  ok "سكربت فحص الشجرة موجود وقابل للتنفيذ: $ASSERT_SCRIPT"
  if "$ASSERT_SCRIPT"; then
    ok "hf_assert_unified_tree.sh: التحقق من الشجرة الموحّدة مرّ بنجاح (لا توجد مخالفات مسجّلة)."
  else
    err "hf_assert_unified_tree.sh: وجد مخالفات في الشجرة الموحّدة – راجع تقارير reports/hf_assert_unified_tree_*.log."
  fi
else
  warn "سكربت hf_assert_unified_tree.sh غير موجود أو غير قابل للتنفيذ – لا يمكن فحص symlink/hardlink تلقائيًا."
fi

# 4) استدعاء سكربت الصحّة الموحّد hf_health_all.sh
section "التحقق من صحة الأنظمة (SmartFriend + FFactory) عبر hf_health_all.sh"

HEALTH_SCRIPT="$ROOT/bin/hf_health_all.sh"
if [[ -x "$HEALTH_SCRIPT" ]]; then
  ok "سكربت hf_health_all.sh موجود وقابل للتنفيذ: $HEALTH_SCRIPT"
  if "$HEALTH_SCRIPT"; then
    ok "hf_health_all.sh: فحص الصحة اكتمل بنجاح (راجع آخر تقرير في reports/)."
  else
    err "hf_health_all.sh: فحص الصحة أعاد حالة فشل – تحقق من آخر تقرير في reports/hf_health_report_*.log."
  fi
else
  warn "سكربت hf_health_all.sh غير موجود أو غير قابل للتنفيذ – لا يمكن التحقق من صحة السيوت وffactory من داخل HyperFFactory."
fi

# 5) ملخص نهائي
section "الملخص النهائي للتحقق"

echo "عدد الأخطاء:  $errors"
echo "عدد التحذيرات: $warns"

if (( errors == 0 )); then
  echo
  echo "=================================================="
  echo "✅ VERIFIED: مستوى التوثيق والهيكل الحالي متوافق مع ما هو معلن في README/plan_status/docs."
  echo "=================================================="
  exit 0
else
  echo
  echo "=================================================="
  echo "❌ FAILED: هناك $errors مشكلة/مخالفة على الأقل – يجب مراجعتها قبل اعتبار الخطة مكتملة."
  echo "=================================================="
  exit 1
fi
