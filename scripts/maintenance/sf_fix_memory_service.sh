#!/usr/bin/env bash
set -Eeuo pipefail

SERVICE="sf-memory.service"
SERVICE_FILE="/etc/systemd/system/$SERVICE"
LOG_FILE="/opt/smartfriend-suite/reports/memory_debug_$(date '+%Y%m%d_%H%M%S').log"

log(){ echo "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE"; }

diagnose_memory() {
    log "🔍 تشخيص خدمة الذاكرة: $SERVICE"
    
    # 1. التحقق من ملف الخدمة
    log "1. فحص ملف الخدمة:"
    if [[ -f "$SERVICE_FILE" ]]; then
        log "   ✅ الملف موجود: $SERVICE_FILE"
        log "   📋 محتوى ExecStart:"
        grep "ExecStart=" "$SERVICE_FILE" | head -1 | tee -a "$LOG_FILE"
    else
        log "   ❌ ملف الخدمة غير موجود"
        return 1
    fi
    
    # 2. التحقق من الملف القابل للتنفيذ
    log "2. فحص الملف القابل للتنفيذ:"
    EXEC_START=$(grep "ExecStart=" "$SERVICE_FILE" | cut -d'=' -f2 | awk '{print $1}')
    if [[ -n "$EXEC_START" ]]; then
        if [[ -f "$EXEC_START" ]]; then
            log "   ✅ الملف موجود: $EXEC_START"
            if [[ -x "$EXEC_START" ]]; then
                log "   ✅ الملف قابل للتنفيذ"
            else
                log "   ⚠️  الملف غير قابل للتنفيذ - جعلها قابلة للتنفيذ..."
                chmod +x "$EXEC_START" && log "   ✅ تم التصحيح"
            fi
        else
            log "   ❌ الملف غير موجود: $EXEC_START"
        fi
    fi
    
    # 3. التحقق من متغيرات البيئة
    log "3. فحص متغيرات البيئة:"
    ENV_FILES=$(grep "EnvironmentFile=" "$SERVICE_FILE" | cut -d'=' -f2)
    for env_file in $ENV_FILES; do
        if [[ -f "$env_file" ]]; then
            log "   ✅ ملف البيئة موجود: $env_file"
            log "   📋 إعدادات الذاكرة:"
            grep -E "MEMORY|DB|PORT" "$env_file" | head -5 | while read line; do
                log "      $line"
            done
        else
            log "   ❌ ملف البيئة مفقود: $env_file"
        fi
    done
    
    # 4. عرض آخر الأخطاء
    log "4. آخر الأخطاء من اللوج:"
    journalctl -u "$SERVICE" -n 15 --no-pager 2>/dev/null | tail -10 | while read line; do
        log "   📄 $line"
    done
    
    # 5. التحقق من الاعتمادات
    log "5. فحص الاعتمادات:"
    if [[ -f "/opt/smartfriend-suite/bin/sf-service-memory" ]]; then
        log "   ✅ الملف الثنائي موجود"
        # التحقق من مكتبات Python
        if grep -q "python" "$SERVICE_FILE"; then
            log "   🔍 فحص بيئة Python..."
            PYTHON_ENV=$(grep "python" "$SERVICE_FILE" | head -1 | awk '{print $1}')
            if [[ -f "$PYTHON_ENV" ]]; then
                log "   ✅ Python موجود: $PYTHON_ENV"
            fi
        fi
    fi
}

fix_memory_service() {
    log ""
    log "🔧 بدء إصلاح خدمة الذاكرة"
    
    # 1. إيقاف الخدمة
    log "1. إيقاف الخدمة..."
    systemctl stop "$SERVICE" 2>/dev/null && log "   ✅ تم الإيقاف"
    
    # 2. التحقق من المنافذ
    log "2. فحص المنافذ:"
    if ss -tulpn | grep -q ":8214"; then
        log "   ⚠️  المنفذ 8214 مشغول - إطلاقه..."
        fuser -k 8214/tcp 2>/dev/null && log "   ✅ تم تحرير المنفذ"
    else
        log "   ✅ المنفذ 8214 حر"
    fi
    
    # 3. إعادة تحميل systemd
    log "3. إعادة تحميل systemd..."
    systemctl daemon-reload && log "   ✅ تم إعادة التحميل"
    
    # 4. بدء الخدمة
    log "4. بدء الخدمة..."
    if systemctl start "$SERVICE"; then
        log "   ✅ تم بدء الخدمة بنجاح"
        sleep 2
        if systemctl is-active "$SERVICE" >/dev/null; then
            log "   🎉 الخدمة نشطة الآن!"
            return 0
        else
            log "   ❌ الخدمة فشلت في البقاء نشطة"
            return 1
        fi
    else
        log "   ❌ فشل بدء الخدمة"
        return 1
    fi
}

main() {
    log "بدء تشخيص وإصلاح خدمة الذاكرة"
    log "=================================="
    
    diagnose_memory
    fix_memory_service
    
    log ""
    log "📊 النتيجة النهائية:"
    if systemctl is-active "$SERVICE" >/dev/null; then
        log "   ✅ $SERVICE - نشط الآن"
        log "   🌐 التحقق من المنفذ 8214:"
        ss -tulpn | grep ":8214" && log "      📡 الخدمة تستمع على المنفذ" || log "      ⚠️  الخدمة لا تستمع على المنفذ"
    else
        log "   ❌ $SERVICE - لا يزال غير نشط"
        log "   🔍 لعرض الأخطاء الكاملة: journalctl -u $SERVICE -n 20 --no-pager"
    fi
    
    log "تم حفظ التقرير في: $LOG_FILE"
}

main
