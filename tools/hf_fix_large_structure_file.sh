#!/usr/bin/env bash
# إصلاح مشكلة structure.txt مع GitHub (حجم > 100MB)

set -Eeuo pipefail

log() {
    printf '%s %s\n' "$(date -Iseconds)" "$*"
}

log "🚀 بدء إصلاح ملف structure.txt الكبير في HyperFFactory"

# 1) تأكيد أننا داخل مستودع Git
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    log "❌ هذا المجلد ليس مستودع Git. أخرج."
    exit 1
fi

# 2) تأكيد وجود structure.txt (إن وجد)
if [[ -f "structure.txt" ]]; then
    mkdir -p /root/HyperFFactory_backups
    cp -v structure.txt /root/HyperFFactory_backups/structure.txt
    log "✅ تم أخذ نسخة احتياطية من structure.txt في /root/HyperFFactory_backups/structure.txt"
else
    log "ℹ️ الملف structure.txt غير موجود في الجذر (working dir). سنستمر لإزالته من التاريخ فقط."
fi

# 3) تحديث .gitignore لإهمال structure.txt في المستقبل
if [[ -f ".gitignore" ]]; then
    if grep -q '^structure.txt$' .gitignore; then
        log "ℹ️ structure.txt موجود بالفعل في .gitignore"
    else
        printf '\n# Large local-only file\nstructure.txt\n' >> .gitignore
        log "✅ تمت إضافة structure.txt إلى .gitignore"
        git add .gitignore || true
        if git diff --cached --quiet; then
            log "ℹ️ لا توجد تغييرات staged في .gitignore"
        else
            git commit -m "chore: ignore local structure.txt (too large for GitHub)" || log "ℹ️ لم يتم إنشاء commit (ربما لا يوجد تغيير فعلي)"
        fi
    fi
else
    log "ℹ️ .gitignore غير موجود، لن أُعدل عليه."
fi

# 4) إزالة structure.txt من كل الكوميتات في التاريخ (history rewrite)
log "⚙️ بدء إعادة كتابة التاريخ لإزالة structure.txt من Git history..."

git filter-branch --force --index-filter \
  'git rm --cached --ignore-unmatch structure.txt' \
  --prune-empty --tag-name-filter cat -- --all

log "✅ انتهى git filter-branch"

# 5) تنظيف مراجع Git القديمة وتقليل الحجم
log "🧹 تنظيف refs القديمة وتشغيل git gc..."

rm -rf .git/refs/original || true
git reflog expire --expire=now --all || true
git gc --prune=now --aggressive || true

log "✅ تم تنظيف .git بنجاح"

# 6) تأكيد أن structure.txt لم يعد موجودًا في التاريخ
if git log --structure.txt >/dev/null 2>&1; then
    log "⚠️ يبدو أن git log -- structure.txt ما زال يعيد نتائج، راجع يدويًا."
else
    log "✅ structure.txt لم يعد موجودًا في تاريخ Git (أو لا يمكن إيجاده بـ git log -- structure.txt)."
fi

# 7) عرض حالة المستودع وتذكير بأمر push
log "📋 ملخص الحالة بعد الإصلاح:"
git status || true

echo
log "✅ انتهى إصلاح مشكلة structure.txt."
echo
echo "الخطوة الأخيرة (نفّذها يدويًا):"
echo "  git push --force origin main"
echo
log "⚠️ ملاحظة: استخدم --force لأننا أعدنا كتابة تاريخ الفرع main."
