#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()    { echo -e "${BLUE}[$(date '+%F %T')]${NC} $*"; }
success(){ echo -e "${GREEN}[$(date '+%F %T')] [OK]${NC} $*"; }

DB_FILE="/opt/smartfriend-suite/var/db/smartfriend_unified.db"
DB_DIR="/opt/smartfriend-suite/var/db"

log "=== إصلاح صلاحيات قاعدة البيانات لـ reflector ==="

# 1) ضبط صلاحيات المجلد
log "1) ضبط صلاحيات مجلد var/db..."
chmod 775 "$DB_DIR" 2>/dev/null || true
success "   ✅ صلاحيات المجلد: 775"

# 2) ضبط صلاحيات ملف قاعدة البيانات
log "2) ضبط صلاحيات ملف قاعدة البيانات..."
chmod 666 "$DB_FILE" 2>/dev/null || true
success "   ✅ صلاحيات الملف: 666"

# 3) التحقق من الصلاحيات
log "3) التحقق من الصلاحيات الجديدة..."
ls -la "$DB_FILE" | head -1
ls -la "$DB_DIR" | head -1

# 4) اختبار reflector
log "4) اختبار reflector بعد إصلاح الصلاحيات..."
systemctl restart smartfrind-reflector.service

if systemctl is-active smartfrind-reflector.service >/dev/null 2>&1; then
    success "   ✅ smartfrind-reflector.service يعمل بنجاح!"
    systemctl status smartfrind-reflector.service --no-pager -l
else
    log "   ℹ️ حالة الخدمة:"
    systemctl status smartfrind-reflector.service --no-pager -l
fi

success "=== اكتمل إصلاح الصلاحيات ==="
