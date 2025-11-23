#!/usr/bin/env bash
set -euo pipefail

ROOT="/root/HyperFFactory"
cd "$ROOT"

REPORT_DIR="$ROOT/reports"
mkdir -p "$REPORT_DIR"

TS="$(date '+%Y%m%d_%H%M%S')"
LOG_FILE="$REPORT_DIR/hf_fix_escape_symlinks_${TS}.log"

log() {
  echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "=================================================="
log "HF FIX ESCAPE SYMLINKS (SYSTEMD BACKUPS)"
log "ROOT: $ROOT"
log "LOG : $LOG_FILE"
log "=================================================="

ESCAPE_COUNT=0
FIXED_COUNT=0
SKIPPED_COUNT=0

# نفحص symlinks داخل مسارات legacy backup فقط
while IFS= read -r -d '' LINK; do
  TARGET="$(readlink -f "$LINK" 2>/dev/null || readlink "$LINK" 2>/dev/null || true)"

  # نعتبره تهريب فقط لو يشير إلى /etc/systemd/system
  if [[ "$TARGET" == /etc/systemd/system/* ]]; then
    ((ESCAPE_COUNT++))
    log "ESCAPE SYMLINK: $LINK -> $TARGET"

    # أخذ نسخة من ملف الوحدة إن كان موجودًا
    if [[ -f "$TARGET" ]]; then
      BACKUP_FILE="${LINK}.unit.backup"
      if [[ -f "$BACKUP_FILE" ]]; then
        log "INFO: ملف النسخة موجود مسبقًا: $BACKUP_FILE (لن يُستبدل)."
      else
        cp "$TARGET" "$BACKUP_FILE"
        log "OK  : تم نسخ محتوى الوحدة إلى: $BACKUP_FILE"
      fi
    else
      log "WARN: الملف الهدف غير موجود فعليًا: $TARGET (لن يتم أخذ نسخة محتوى)."
    fi

    # حفظ مسار الهدف في ملف نصي
    META_FILE="${LINK}.target_path.txt"
    if [[ -f "$META_FILE" ]]; then
      log "INFO: ملف المسار موجود مسبقًا: $META_FILE"
    else
      printf '%s\n' "$TARGET" > "$META_FILE"
      log "OK  : تم تسجيل مسار الهدف في: $META_FILE"
    fi

    # حذف symlink الهارب
    rm "$LINK"
    ((FIXED_COUNT++))
    log "OK  : تم حذف symlink الهارب (مع تعويضه بالنسخ/الميتاداتا)."
  else
    ((SKIPPED_COUNT++))
  fi
done < <(find "$ROOT/opt/_root_legacy_"* -type l -print0 2>/dev/null || true)

log "--------------------------------------------------"
log "إجمالي symlinks المفحوصة     : $((ESCAPE_COUNT + SKIPPED_COUNT))"
log "عدد symlinks الهاربة المعالجة : $FIXED_COUNT"
log "عدد symlinks المتجاوزة       : $SKIPPED_COUNT"
log "--------------------------------------------------"
log "انتهى إصلاح symlinks الهاربة."
log "يفضل الآن تشغيل: bin/hf_assert_unified_tree.sh"
log "للتأكد من خلو التقارير من أي Escape."
log "=================================================="
