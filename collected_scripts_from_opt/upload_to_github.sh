#!/bin/bash

# سكريبت رفع الملفات إلى GitHub
# يجب تعديل المتغيرات حسب حسابك

set -e

echo "🚀 بدء رفع الملفات إلى GitHub..."

# ⚠️ ⚠️ ⚠️ غير هذه المتغيرات حسب حسابك ⚠️ ⚠️ ⚠️
GITHUB_USERNAME="YOUR_GITHUB_USERNAME"
REPO_NAME="smartfriend-complete-system"
GITHUB_TOKEN="YOUR_GITHUB_TOKEN"
SOURCE_DIR="/root/light-repos"  # المجلد الذي تريد رفعه

# التحقق من المتغيرات
if [ "$GITHUB_USERNAME" == "YOUR_GITHUB_USERNAME" ]; then
    echo "❌ لم تعدل المتغيرات! فضلاً غير:"
    echo "   - GITHUB_USERNAME"
    echo "   - REPO_NAME" 
    echo "   - GITHUB_TOKEN"
    echo "   - SOURCE_DIR"
    exit 1
fi

# التحقق من المجلد المصدري
if [ ! -d "$SOURCE_DIR" ]; then
    echo "❌ المجلد $SOURCE_DIR غير موجود"
    exit 1
fi

echo "📁 المصدر: $SOURCE_DIR"
echo "🔗 الريبو: $REPO_NAME"
echo "👤 المستخدم: $GITHUB_USERNAME"

# إنشاء ريبو جديد على GitHub
create_github_repo() {
    echo "🌐 جاري إنشاء الريبو على GitHub..."
    curl -u "$GITHUB_USERNAME:$GITHUB_TOKEN" https://api.github.com/user/repos -d "{
        \"name\": \"$REPO_NAME\",
        \"description\": \"SmartFriend Complete System - Uploaded via script\",
        \"auto_init\": false,
        \"private\": false
    }"
    echo "✅ تم إنشاء الريبو: https://github.com/$GITHUB_USERNAME/$REPO_NAME"
}

# تهيئة Git ورفع الملفات
upload_files() {
    echo "📥 جاري تهيئة Git..."
    cd "$SOURCE_DIR"
    
    # تهيئة Git
    git init
    git config user.name "$GITHUB_USERNAME"
    git config user.email "$GITHUB_USERNAME@users.noreply.github.com"
    
    # إضافة جميع الملفات
    git add .
    
    # عمل commit
    git commit -m "رفع المشروع الكامل - $(date)"
    
    # إضافة remote
    git remote add origin "https://$GITHUB_TOKEN@github.com/$GITHUB_USERNAME/$REPO_NAME.git"
    
    # رفع الملفات
    echo "⬆️ جاري رفع الملفات إلى GitHub..."
    git branch -M main
    git push -u origin main
    
    echo "✅ تم الرفع بنجاح!"
}

# التنفيذ الرئيسي
main() {
    echo "🔍 التحقق من المتطلبات..."
    command -v git >/dev/null 2>&1 || { echo "❌ Git غير مثبت"; exit 1; }
    command -v curl >/dev/null 2>&1 || { echo "❌ curl غير مثبت"; exit 1; }
    
    create_github_repo
    upload_files
    
    echo ""
    echo "🎉 اكتمل الرفع!"
    echo "📎 الرابط: https://github.com/$GITHUB_USERNAME/$REPO_NAME"
    echo ""
    echo "🔗 يمكنك الآن مشاركة الرابط معي لمشاهدة الملفات"
}

main
