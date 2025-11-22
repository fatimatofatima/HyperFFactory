#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

BLUE='\033[0;34m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log()   { echo -e "${BLUE}[$(date '+%F %T')]${NC} $*"; }
warn()  { echo -e "${YELLOW}[$(date '+%F %T')] [WARN] ${NC}$*" >&2; }
error() { echo -e "${RED}[$(date '+%F %T')] [ERROR] ${NC}$*" >&2; }
ok()    { echo -e "${GREEN}[$(date '+%F %T')] [OK] ${NC}$*"; }

ROOT="/opt/smartfriend-suite"
CANON_DB="$ROOT/var/db/smartfriend_unified.db"
LEGACY1="$ROOT/data/db/smartfriend_unified.db"
LEGACY2="$ROOT/data/smartfriend_unified.db"
TS="$(date +%Y%m%d_%H%M%S)"

log "=== إزالة أي symlink لـ smartfriend_unified.db والإبقاء على قاعدة واحدة رسمية ==="

# 1) تأكيد وجود القاعدة الرسمية
if [[ ! -f "$CANON_DB" ]]; then
  error "لم يتم العثور على القاعدة الرسمية: $CANON_DB"
  error "توقف بدون أي تعديل."
  exit 1
fi

log "القاعدة الرسمية الحالية:"
ls -lh "$CANON_DB" || true

# 2) نسخة احتياطية قبل أي تعديل
BACKUP="/root/smartfriend_unified.db.before_remove_symlinks.$TS"
log "أخذ نسخة احتياطية إلى: $BACKUP"
cp -a "$CANON_DB" "$BACKUP"
ok "تم إنشاء النسخة الاحتياطية."

# 3) عرض حالة المسارات قبل التعديل
log "حالة المسارات قبل التعديل:"
for p in "$LEGACY1" "$LEGACY2"; do
  if [[ -L "$p" ]]; then
    echo "  [LINK] $p -> $(readlink -f "$p")"
  elif [[ -e "$p" ]]; then
    echo "  [FILE] $p (ملف حقيقي، لن ألمسه في هذا السكربت)"
  else
    echo "  [NONE] $p غير موجود."
  fi
done

# 4) إزالة السيم لينكات فقط (بدون لمس أي ملف حقيقي)
log "إزالة أي symlink فقط (بدون حذف أي قاعدة بيانات حقيقية)..."
for p in "$LEGACY1" "$LEGACY2"; do
  if [[ -L "$p" ]]; then
    rm "$p"
    ok "تم حذف symlink: $p"
  fi
done

# 5) تأكيد عدم وجود symlink آخر باسم smartfriend_unified.db داخل المشروع
log "فحص أي symlink متبقي باسم smartfriend_unified.db تحت $ROOT ..."
SYMLINKS_FOUND="$(find "$ROOT" -maxdepth 5 -type l -name 'smartfriend_unified.db' -print || true)"
if [[ -n "$SYMLINKS_FOUND" ]]; then
  warn "لا يزال هناك symlink واحد أو أكثر:"
  echo "$SYMLINKS_FOUND"
else
  ok "لا يوجد أي symlink باسم smartfriend_unified.db داخل $ROOT الآن."
fi

# 6) عرض حالة المسارات بعد التعديل
log "حالة المسارات بعد التعديل:"
for p in "$LEGACY1" "$LEGACY2"; do
  if [[ -L "$p" ]]; then
    echo "  [LINK] $p -> $(readlink -f "$p")"
  elif [[ -e "$p" ]]; then
    echo "  [FILE] $p"
  else
    echo "  [NONE] $p غير موجود."
  fi
done

# 7) تأكيد بقاء القاعدة الرسمية كما هي
log "تأكيد القاعدة الرسمية بعد التعديلات:"
ls -lh "$CANON_DB" || true

ok "اكتمل تنظيف السيم لينكات الخاصة بـ smartfriend_unified.db بدون المساس بـ ffactory."
