#!/usr/bin/env bash
# HyperFFactory – Internal Files Index
# إنشاء فهرس داخلي للملفات والمجلدات داخل الشجرة الموحّدة فقط.
#
# المخرجات:
#   - تقرير نصي في logs/
#   - ملف TSV مفصّل في reports/ باسم:
#       reports/hf_internal_index_YYYYMMDD_HHMMSS.tsv
#
# الأعمدة في ملف الـ TSV:
#   kind            : file / dir / link
#   path_rel        : المسار النسبي من ROOT (بدون ./)
#   path_abs        : المسار المطلق الكامل
#   size_bytes      : الحجم بالبايت (0 للمجلدات، حجم اللينك نفسه للـ symlink)
#   in_git          : YES/NO (للملفات فقط، N/A لغيرها أو إذا لم يكن Git متاحًا)
#   symlink_target  : هدف الرابط الرمزي (إن وجد؛ فارغ لغير ذلك)

set -Eeuo pipefail

ROOT="/root/HyperFFactory"
LOG_DIR="$ROOT/logs"
REPORT_DIR="$ROOT/reports"

mkdir -p "$LOG_DIR" "$REPORT_DIR"

STAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$LOG_DIR/hf_internal_index_${STAMP}.log"
OUT_FILE="$REPORT_DIR/hf_internal_index_${STAMP}.tsv"
GIT_LIST="$REPORT_DIR/.hf_git_tracked_${STAMP}.lst"

exec > >(tee -a "$LOG_FILE") 2>&1

log() {
    printf '%s %s\n' "$(date -Iseconds)" "$*"
}

log "============================================================"
log "== HyperFFactory – Internal Files Index"
log "============================================================"
log "ROOT   : $ROOT"
log "LOG    : $LOG_FILE"
log "OUTPUT : $OUT_FILE"
log "============================================================"

cd "$ROOT"

# 1) تجهيز قائمة الملفات المتتبعة في Git (إن كان هذا المجلد Git repo)
IN_GIT_MODE="NO"
if command -v git >/dev/null 2>&1 && [ -d "$ROOT/.git" ]; then
    if git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        log "ℹ️ داخل مستودع Git – إنشاء قائمة الملفات المتتبعة..."
        if git -C "$ROOT" ls-files > "$GIT_LIST" 2>/dev/null; then
            IN_GIT_MODE="YES"
            log "ℹ️ تم إنشاء قائمة الملفات المتتبعة: $GIT_LIST"
        else
            log "⚠️ تعذّر إنشاء قائمة الملفات المتتبعة من Git (سيتم تجاهل in_git)."
        fi
    else
        log "ℹ️ هذا المجلد لا يُعامل الآن كـ Git work-tree (تخطي فحص in_git)."
    fi
else
    log "ℹ️ git غير متوفر أو .git غير موجود – لن يتم حساب in_git."
fi

# 2) كتابة الهيدر لملف الفهرس
printf 'kind\tpath_rel\tpath_abs\tsize_bytes\tin_git\tsymlink_target\n' > "$OUT_FILE"

# 3) مسح الشجرة – بدون تتبّع symlinks، مع استثناء بعض المسارات الكبيرة/الحساسة إن لزم
log "ℹ️ بدء مسح الشجرة الداخلية (بدون تتبّع symlinks)..."

COUNT_TOTAL=0

# نستخدم find مع -print0 للتعامل مع المسارات التي تحتوي على مسافات
find . -mindepth 1 \
    \( -path './.git' -o -path './logs' -o -path './reports' -o -path './.venv' \) -prune -o \
    -print0 |
while IFS= read -r -d '' P; do
    COUNT_TOTAL=$((COUNT_TOTAL + 1))

    # إزالة ./ من البداية
    REL="${P#./}"
    ABS="$ROOT/$REL"

    KIND=""
    SIZE="0"
    IN_GIT="N/A"
    SYM_TARGET=""

    if [ -L "$P" ]; then
        KIND="link"
        # حجم اللينك نفسه
        SIZE="$(stat -c '%s' "$P" 2>/dev/null || echo 0)"
        SYM_TARGET="$(readlink "$P" 2>/dev/null || echo '')"
    elif [ -d "$P" ]; then
        KIND="dir"
        SIZE="0"
    elif [ -f "$P" ]; then
        KIND="file"
        SIZE="$(stat -c '%s' "$P" 2>/dev/null || echo 0)"
        if [ "$IN_GIT_MODE" = "YES" ] && [ -s "$GIT_LIST" ]; then
            if grep -qx "$REL" "$GIT_LIST"; then
                IN_GIT="YES"
            else
                IN_GIT="NO"
            fi
        else
            IN_GIT="N/A"
        fi
    else
        # نوع غير معروف (جهاز، سوكِت، إلخ) – نسجلها كـ other
        KIND="other"
        SIZE="$(stat -c '%s' "$P" 2>/dev/null || echo 0)"
    fi

    # كتابة السطر في ملف الـ TSV
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$KIND" \
        "$REL" \
        "$ABS" \
        "$SIZE" \
        "$IN_GIT" \
        "$SYM_TARGET" \
        >> "$OUT_FILE"

done

log "ℹ️ انتهى المسح – عدد العناصر الإجمالي (تقريبي من loop): $COUNT_TOTAL"
log "ℹ️ تم إنشاء فهرس داخلي في: $OUT_FILE"
log "============================================================"
log "✓ انتهى إنشاء الفهرس الداخلي للملفات والمجلدات."
log "============================================================"
