#!/usr/bin/env bash
# HyperFFactory – Safe Git Sync from server to GitHub (no force, no main touch)

set -euo pipefail

ROOT_DIR="/root/HyperFFactory"
REMOTE_URL="https://github.com/fatimatofatima/HyperFFactory.git"

cd "$ROOT_DIR" || { echo "❌ لا يمكن الدخول إلى $ROOT_DIR"; exit 1; }

if ! command -v git >/dev/null 2>&1; then
  echo "❌ git غير مُثبَّت. ثبّتيه أولاً: apt-get update && apt-get install -y git"
  exit 1
fi

echo "== HyperFFactory – Safe Git Sync =="
echo "📁 ROOT   : $ROOT_DIR"
echo "🌐 REMOTE : $REMOTE_URL"
echo

# 1) تأكيد إننا داخل ريبو git
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "❌ المجلد الحالي ليس مستودع Git."
  exit 1
fi

# 2) إعداد/فحص remote origin
if git remote get-url origin >/dev/null 2>&1; then
  CURRENT_URL="$(git remote get-url origin)"
  echo "🔹 origin موجود بالفعل: $CURRENT_URL"
  if [[ "$CURRENT_URL" != "$REMOTE_URL" ]]; then
    echo "⚠️ تحذير: عنوان origin الحالي مختلف عن:"
    echo "   $REMOTE_URL"
    echo "   لن أغيّره تلقائيًا. لو حابة تعدليه:"
    echo "   git remote set-url origin \"$REMOTE_URL\""
  fi
else
  echo "ℹ️ لا يوجد remote باسم origin – سيتم إنشاؤه الآن."
  git remote add origin "$REMOTE_URL"
fi

# 3) fetch خفيف
echo
echo "📥 git fetch origin (بدون دمج)..."
git fetch origin || echo "⚠️ تحذير: فشل fetch (ربما أول مرة أو لا يوجد access حالياً)."

# 4) إنشاء اسم برانش بناءً على الوقت
TS="$(date +%Y%m%d_%H%M)"
BRANCH_NAME="server-sync-${TS}"

echo
echo "🪵 حالة العمل الحالية (قبل إنشاء البرانش):"
git status --short || true

echo
echo "🌿 إنشاء برانش جديد لحالة السيرفر: $BRANCH_NAME"
git checkout -b "$BRANCH_NAME"

# 5) فحص وجود تغييرات
if git status --short | grep -q .; then
  echo
  echo "➕ إضافة كل تغييرات السيرفر (tracked + untracked) إلى الـ commit"
  git add -A

  echo
  echo "📝 إنشاء commit لحالة السيرفر الحالية..."
  git commit -m "Server snapshot ${TS} from vmi2733174"

  echo
  echo "🚀 رفع البرانش إلى GitHub: origin/$BRANCH_NAME"
  git push origin "$BRANCH_NAME"

  echo
  echo "✅ تم رفع حالة السيرفر في برانش جديد:"
  echo "   branch: $BRANCH_NAME"
  echo "   remote: origin/$BRANCH_NAME"
  echo
  echo "💡 ملاحظة:"
  echo "   - لم يتم لمس main ولا أي history."
  echo "   - كل التغييرات الآن موجودة في برانش مستقل تقدر تراجعيه من GitHub."
else
  echo
  echo "ℹ️ لا توجد تغييرات محلية لرفعها (working tree نظيف)."
  echo "   لن يتم إنشاء commit أو push."
fi

echo
echo "🏁 Safe Git Sync انتهى."
