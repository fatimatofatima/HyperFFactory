#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

log()    { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
info()   { log "INFO  - $*"; }
warn()   { log "WARN  - $*"; }
error()  { log "ERROR - $*"; }

SITES_ENABLED_DIR="/etc/nginx/sites-enabled"
SITES_AVAILABLE_DIR="/etc/nginx/sites-available"
BACKUP_DIR="/etc/nginx/sites-backup-$(date +%Y%m%d_%H%M%S)"
CONF_MAIN="$SITES_ENABLED_DIR/smartfriend.conf"

main() {
    info "بدء إصلاح Nginx + Memory Routing"

    # 1) إنشاء مجلد نسخ احتياطية لملفات الـ sites
    info "إنشاء مجلد النسخ الاحتياطي: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"

    # 2) نقل أي ملفات backup من sites-enabled للخارج (خاصة smartfriend.conf.backup)
    info "نقل ملفات *.backup من $SITES_ENABLED_DIR إلى $BACKUP_DIR (إن وجدت)"
    shopt -s nullglob
    local f
    for f in "$SITES_ENABLED_DIR"/*.backup "$SITES_ENABLED_DIR"/*~; do
        if [ -f "$f" ]; then
            info "نقل الملف الاحتياطي: $(basename "$f") → $BACKUP_DIR"
            mv "$f" "$BACKUP_DIR/"
        fi
    done
    shopt -u nullglob

    # 3) التأكد من أن ملف smartfriend.conf موجود
    if [ ! -f "$CONF_MAIN" ]; then
        error "ملف Nginx الرئيسي للسيوت غير موجود: $CONF_MAIN"
        error "لن أستطيع تعديل توجيه /memory/، راجع المسار أولاً."
        exit 1
    fi

    # 4) تعديل توجيه Memory من 8214 إلى 8211 (اعتماداً على أن memory-fixed يستمع على 8211)
    info "تعديل أي ظهور للبورت 8214 إلى 8211 داخل $CONF_MAIN (إن وجد)"
    if grep -q "8214" "$CONF_MAIN"; then
        cp "$CONF_MAIN" "$BACKUP_DIR/$(basename "$CONF_MAIN").pre_memory_fix"
        sed -i 's/127\.0\.0\.1:8214/127.0.0.1:8211/g' "$CONF_MAIN"
        info "تم استبدال 127.0.0.1:8214 بـ 127.0.0.1:8211 (نسخة قبل التعديل محفوظة في $BACKUP_DIR)"
    else
        warn "لم أجد البورت 8214 داخل $CONF_MAIN؛ ربما التوجيه مضبوط أصلاً أو يستخدم قيمة مختلفة."
    fi

    # 5) فحص إعدادات Nginx بعد التنظيف والتعديل
    info "تشغيل nginx -t للتحقق من الإعدادات..."
    if nginx -t; then
        info "nginx -t ناجح، سيتم إعادة تحميل الخدمة."
        systemctl reload nginx
    else
        error "nginx -t فشل. تم ترك النسخ الاحتياطية في: $BACKUP_DIR"
        exit 1
    fi

    # 6) اختبار /memory/health عبر Nginx بعد الإصلاح
    if command -v curl >/dev/null 2>&1; then
        info "اختبار /memory/health عبر Nginx..."
        curl -sS -m 5 http://127.0.0.1/memory/health || warn "فشل الوصول إلى /memory/health بعد الإصلاح."
        echo
    else
        warn "curl غير متوفر؛ لن يتم اختبار HTTP تلقائياً."
    fi

    info "إصلاح Nginx + Memory Routing انتهى."
    info "الملفات الاحتياطية محفوظة في: $BACKUP_DIR"
}

main "$@"
