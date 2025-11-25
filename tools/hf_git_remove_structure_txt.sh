#!/usr/bin/env bash
# HyperFFactory – إزالة structure.txt الضخم من تاريخ Git بدون فقد النسخة المحلية

set -Eeuo pipefail

ROOT="/root/HyperFFactory"
cd "$ROOT"

LOG_DIR="$ROOT/reports"
mkdir -p "$LOG_DIR"
TS="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$LOG_DIR/hf_git_remove_structure_txt_${TS}.log"

log() {
    printf '%s %s\n' "$(date -Iseconds)" "$*" | tee -a "$LOG_FILE"
}

SECTION() {
    echo | tee -a "$LOG_FILE"
    echo "============================================================" | tee -a "$LOG_FILE"
    echo "== $*" | tee -a "$LOG_FILE"
    echo "============================================================" | tee -a "$LOG_FILE"
}

FILE_NAME="structure.txt"

SECTION "1) فحص وجود structure.txt في الـ working tree"
if [ -f "$FILE_NAME" ]; then
    mkdir -p local_only
    LOCAL_COPY="local_only/${FILE_NAME}.bak_${TS}"
    log "نسخ $FILE_NAME إلى $LOCAL_COPY للاحتفاظ بنسخة محلية..."
    cp -n "$FILE_NAME" "$LOCAL_COPY"
else
    log "⚠️ $FILE_NAME غير موجود في working tree، نتابع لإزالته من التاريخ فقط."
fi

SECTION "2) التأكد من توفر git filter-repo"

# نحتاج git filter-repo (يفضّل يكون مثبت كأمر git filter-repo)
if git filter-repo -h >/dev/null 2>&1; then
    log "✅ git filter-repo متوفر."
else
    log "❌ git filter-repo غير متوفر على هذا السيرفر."
    log "   من فضلك ثبّته أولاً (مثال):"
    log "   pip install git-filter-repo"
    log "   أو اتبع توثيق Git الرسمي."
    log "إيقاف السكربت الآن بدون أي تعديل على Git."
    exit 1
fi

SECTION "3) إزالة structure.txt من كل تاريخ Git (قد يستغرق وقتاً)"

log "تشغيل: git filter-repo --path \"$FILE_NAME\" --invert-paths"
git filter-repo --path "$FILE_NAME" --invert-paths 2>&1 | tee -a "$LOG_FILE"

SECTION "4) التأكد من أن structure.txt لن يُتتبّع مرة أخرى"

if [ -f ".gitignore" ]; then
    if grep -Fxq "$FILE_NAME" .gitignore; then
        log ".gitignore يحتوي بالفعل على $FILE_NAME"
    else
        log "إضافة $FILE_NAME إلى .gitignore"
        echo "$FILE_NAME" >> .gitignore
    fi
else
    log ".gitignore غير موجود، إنشاؤه وإضافة $FILE_NAME"
    echo "$FILE_NAME" > .gitignore
fi

git add .gitignore || log "⚠️ فشل git add .gitignore (يمكن مراجعتها يدويًا)"

SECTION "5) إنشاء كوميت تنظيف (إن وجد ما في stage)"

if git diff --cached --quiet; then
    log "لا يوجد أي تغيير في stage بعد عملية التنظيف، لن يتم إنشاء كوميت جديد."
else
    COMMIT_MSG="chore: remove large structure.txt from history & update ignore @ ${TS}"
    log "إنشاء كوميت: $COMMIT_MSG"
    git commit -m "$COMMIT_MSG" 2>&1 | tee -a "$LOG_FILE" || log "⚠️ git commit فشل"
fi

SECTION "6) تذكير بأمر push المطلوب"

log "الخطوة التالية (يدويًا – من فضلك نفّذ بنفسك بعد التأكد):"
log "  git push origin main --force-with-lease"

log "ملاحظة:"
log "- هذا السكربت أعاد كتابة تاريخ الفرع المحلي لإزالة structure.txt."
log "- تأكد أنه لا يوجد أحد آخر يعمل على نفس الريبو قبل الـ push بالـ force."

SECTION "7) حالة Git النهائية (مختصرة)"
git status --short | tee -a "$LOG_FILE" || log "⚠️ git status فشل"

log "انتهى hf_git_remove_structure_txt.sh"
