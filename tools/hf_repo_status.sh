#!/usr/bin/env bash
# HyperFFactory – Git repo status report

set -Eeuo pipefail

ROOT="/root/HyperFFactory"
REPO_URL="https://github.com/fatimatofatima/HyperFFactory"

log() {
    echo "[$(date +'%F %T')] $*"
}

echo "=================================================="
log "HyperFFactory – تقرير حالة مستودع Git"
echo "ROOT : $ROOT"
echo "REPO : $REPO_URL"
echo "=================================================="

if [ ! -d "$ROOT" ]; then
    log "❌ المجلد $ROOT غير موجود"
    exit 1
fi

cd "$ROOT"

if [ ! -d ".git" ]; then
    log "❌ هذا المجلد ليس مستودع Git (لا يوجد .git)"
    exit 1
fi

log "1) التحقق من أن العمل داخل مستودع Git"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    log "❌ ليس داخل work-tree صحيح"
    exit 1
}

log "2) معلومات الريموت (origin)"
if git remote get-url origin >/dev/null 2>&1; then
    git remote -v
else
    log "⚠️ لا يوجد ريموت origin مضبوط"
fi

log "3) الفرع الحالي"
BRANCH="$(git symbolic-ref --short HEAD 2>/dev/null || echo 'UNKNOWN')"
echo "الفرع الحالي: $BRANCH"

log "4) آخر 5 كوميت"
git log --oneline -5 || log "⚠️ لا يمكن قراءة log"

log "5) حالة الملفات (git status --short)"
git status --short || log "⚠️ لا يمكن تنفيذ git status"

log "6) حالة التقدّم/التأخر عن origin (إن وجد)"
if git remote get-url origin >/dev/null 2>&1; then
    git fetch origin "$BRANCH" >/dev/null 2>&1 || log "⚠️ فشل git fetch origin $BRANCH (تحقق من الاتصال أو اسم الفرع)"
    # عرض حالة مختصرة مع ahead/behind
    git status -sb || true
else
    log "⚠️ لا يوجد origin لمقارنته"
fi

echo "=================================================="
log "انتهى تقرير حالة مستودع HyperFFactory"
echo "=================================================="
