#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

# ألوان للتنسيق
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log(){ echo -e "${BLUE}[$(date '+%F %T')]${NC} $*"; }
warn(){ echo -e "${YELLOW}[$(date '+%F %T')] [WARN]${NC} $*" >&2; }
error(){ echo -e "${RED}[$(date '+%F %T')] [ERROR]${NC} $*" >&2; }
success(){ echo -e "${GREEN}[$(date '+%F %T')] [SUCCESS]${NC} $*"; }

log "=== إصلاح مخصص لخدمات تيليجرام فقط ==="
echo

# خدمات تيليجرام التي نريد إصلاحها
TELEGRAM_SERVICES=(
    "sf-telegram.service"
    "sf-smartfrind.service" 
    "sf-smartfactory.service"
    "sf-telegram-audit.service"
    "smartfrind-bot.service"
    "sf-bot.service"
)

# 1) فحص حالة الخدمات
log "1️⃣ فحص حالة خدمات تيليجرام..."
for service in "${TELEGRAM_SERVICES[@]}"; do
    if systemctl list-unit-files "$service" &>/dev/null; then
        status=$(systemctl is-active "$service" 2>/dev/null || echo "inactive")
        failed=$(systemctl is-failed "$service" 2>/dev/null || echo "not-failed")
        
        if [ "$status" = "active" ]; then
            success "   ✅ $service - نشط"
        elif [ "$failed" = "failed" ]; then
            error "   ❌ $service - فاشل"
        else
            warn "   ⚠️ $service - غير نشط"
        fi
    else
        warn "   🔶 $service - غير موجود"
    fi
done

# 2) فحص ملفات التوكنات
log "2️⃣ فحص ملفات التوكنات..."
TOKEN_FILES=(
    "/etc/smartfriend/sf-telegram.env"
    "/etc/smartfriend/sf-smartfactory.env"
    "/etc/smartfrind/bot.env"
)

for token_file in "${TOKEN_FILES[@]}"; do
    if [ -f "$token_file" ] && [ -s "$token_file" ]; then
        success "   ✅ $token_file - موجود"
        # عرض أول 3 أسطر (بدون عرض القيم الحساسة كاملة)
        echo "     محتوى الملف:"
        head -3 "$token_file" | sed 's/=.*/=***مخفى***/' | while read line; do
            echo "       $line"
        done
    else
        error "   ❌ $token_file - غير موجود أو فارغ"
    fi
done

# 3) تشخيص الأعطال
log "3️⃣ تشخيص الأعطال في خدمات تيليجرام..."
for service in "${TELEGRAM_SERVICES[@]}"; do
    if systemctl is-failed "$service" >/dev/null 2>&1; then
        log "   🔍 تشخيص $service:"
        
        # عرض آخر الأخطاء
        journalctl -u "$service" -n 5 --no-pager | grep -iE "(error|fail|invalid|exception)" | head -3 | while read line; do
            echo "     $line"
        done || echo "     لا توجد أخطاء واضحة في السجلات"
        
        # فحص نوع الخطأ
        if journalctl -u "$service" -n 10 | grep -qi "invalid.token"; then
            error "     📱 مشكلة في توكن التليجرام - غير صالح"
        elif journalctl -u "$service" -n 10 | grep -qi "permission"; then
            warn "     🔐 مشكلة في الصلاحيات"
        elif journalctl -u "$service" -n 10 | grep -qi "import"; then
            warn "     📚 مشكلة في استيراد المكتبات"
        else
            warn "     ⚠️ سبب غير محدد - يحتاج فحص يدوي"
        fi
        echo
    fi
done

# 4) إصلاح الخدمات الفاشلة
log "4️⃣ محاولة إصلاح الخدمات الفاشلة..."
for service in "${TELEGRAM_SERVICES[@]}"; do
    if systemctl is-failed "$service" >/dev/null 2>&1; then
        log "   🔧 إصلاح $service"
        
        # إعادة تعيين حالة الفشل
        systemctl reset-failed "$service"
        
        # محاولة التشغيل
        if systemctl start "$service"; then
            success "     ✅ تم تشغيل $service بنجاح"
            # الانتظار قليلاً والتحقق من الاستقرار
            sleep 2
            if systemctl is-active "$service" >/dev/null 2>&1; then
                success "     ✅ $service مستقر الآن"
            else
                warn "     ⚠️ $service توقف بعد التشغيل"
            fi
        else
            error "     ❌ فشل تشغيل $service"
            
            # محاولة إعادة التشغيل القسري
            systemctl restart "$service" && success "     ✅ أعيد تشغيل $service" || error "     ❌ فشل إعادة التشغيل"
        fi
        echo
    fi
done

# 5) فحص نهائي للحالة
log "5️⃣ الحالة النهائية لخدمات تيليجرام..."
ACTIVE_COUNT=0
FAILED_COUNT=0
INACTIVE_COUNT=0

for service in "${TELEGRAM_SERVICES[@]}"; do
    if systemctl is-active "$service" >/dev/null 2>&1; then
        success "   ✅ $service - نشط"
        ((ACTIVE_COUNT++))
    elif systemctl is-failed "$service" >/dev/null 2>&1; then
        error "   ❌ $service - فاشل"
        ((FAILED_COUNT++))
    else
        warn "   ⚠️ $service - غير نشط"
        ((INACTIVE_COUNT++))
    fi
done

echo
log "📊 إحصائيات الإصلاح:"
echo "   • ✅ نشط: $ACTIVE_COUNT"
echo "   • ❌ فاشل: $FAILED_COUNT" 
echo "   • ⚠️ غير نشط: $INACTIVE_COUNT"

# 6) توصيات نهائية
echo
log "💡 التوصيات النهائية:"
if [ $FAILED_COUNT -gt 0 ]; then
    error "   ❌ هناك خدمات فاشلة تحتاج انتباه:"
    for service in "${TELEGRAM_SERVICES[@]}"; do
        if systemctl is-failed "$service" >/dev/null 2>&1; then
            echo "     - $service"
        fi
    done
    echo
    warn "   🔧 الإجراءات المطلوبة:"
    echo "     1. تحقق من صحة التوكنات في /etc/smartfriend/"
    echo "     2. تأكد من أن التوكنات غير منتهية الصلاحية"
    echo "     3. استخدم: journalctl -u <service> لمزيد من التفاصيل"
    echo "     4. قد تحتاج لتحديث التوكنات يدوياً"
fi

if [ $ACTIVE_COUNT -gt 0 ]; then
    success "   ✅ الخدمات النشطة تعمل بشكل صحيح"
fi

echo
success "=== تم الانتهاء من إصلاح خدمات تيليجرام ==="

