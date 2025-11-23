#!/bin/bash

# =============================================
# 🏭 HyperFFactory - مدير التحديثات على الريبو
# =============================================

set -euo pipefail

# التكوين الأساسي
REPO_DIR="/root/HyperFFactory"
GIT_REMOTE="origin"
GIT_BRANCH="main"
BACKUP_DIR="${REPO_DIR}/backups/auto"
LOG_FILE="${REPO_DIR}/logs/repo_manager.log"

# ألوان لل output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# وظائف المساعدة
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[تحذير]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[خطأ]${NC} $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[معلومات]${NC} $1" | tee -a "$LOG_FILE"
}

# إنشاء الدلائل المطلوبة
setup_directories() {
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$(dirname "$LOG_FILE")"
    mkdir -p "${REPO_DIR}/docs/progress"
    mkdir -p "${REPO_DIR}/docs/plans"
}

# نسخ احتياطي تلقائي
auto_backup() {
    local backup_file="${BACKUP_DIR}/backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    log "إنشاء نسخة احتياطية تلقائية..."
    
    tar -czf "$backup_file" \
        --exclude='.git' \
        --exclude='.venv' \
        --exclude='__pycache__' \
        --exclude='*.log' \
        -C "$REPO_DIR" . 2>/dev/null || true
        
    log "✅ النسخة الاحتياطية جاهزة: $(basename "$backup_file")"
}

# فحص حالة الريبو
check_repo_status() {
    log "فحص حالة الريبو..."
    
    cd "$REPO_DIR"
    
    # التحقق من اتصال الريبو
    if ! git remote get-url "$GIT_REMOTE" &>/dev/null; then
        error "الريبو غير متصل بال remote"
        return 1
    fi
    
    # التحقق من التغييرات
    if git status --porcelain | grep -q .; then
        info "يوجد تغييرات تحتاج commit"
        git status --short
        return 2
    else
        log "✅ لا يوجد تغييرات جديدة"
        return 0
    fi
}

# تحديث ملف تقدم المشروع
update_progress_tracker() {
    local progress_file="${REPO_DIR}/docs/progress/PROJECT_TRACKER.md"
    
    cat > "$progress_file" << 'PROGRESSEOF'
# 📊 متتبع تقدم HyperFFactory

## 🎯 حالة المشروع الشاملة

### المرحلة 1: البنية الأساسية ✅
- [x] تجميع الكود من `/opt`
- [x] بيئة Python مع 161 حزمة
- [x] Docker Stack (10 خدمات)
- [x] FastAPI Gateway (منفذ 8310)
- [x] Systemd Service

### المرحلة 2: النظام الإداري 🚧
- [x] العقل المدير المركزي
- [x] مدير نظام العمليات
- [ ] مدير نظام الجودة
- [ ] مدير نظام الموارد
- [ ] قواعد البيانات الإدارية

### المرحلة 3: نظام التعلم الذاتي 🔴
- [ ] آلية التعلم الآلي
- [ ] تحسين الأداء التلقائي
- [ ] تنبؤ المشاكل

## 📈 الإحصائيات الحالية

\`\`\`
$(date +"%Y-%m-%d %H:%M:%S")
• الملفات البرمجية: $(find "$REPO_DIR" -name "*.py" -type f | wc -l)
• قواعد البيانات: $(find "$REPO_DIR/var/db" -name "*.db" -type f 2>/dev/null | wc -l)
• الخدمات النشطة: $(docker ps -q | wc -l)
• الحزم المثبتة: $(find "$REPO_DIR/.venv" -name "*.py" -type f 2>/dev/null | wc -l || echo "N/A")
\`\`\`

## 🗓️ الجدول الزمني

### هذا الأسبوع:
- [ ] إكمال مدير نظام الجودة
- [ ] بناء واجهات API للإدارة
- [ ] ربط قواعد البيانات

### الأسبوع القادم:
- [ ] نظام التعلم الذاتي
- [ ] واجهات المراقبة
- [ ] اختبار التكامل

## 🔄 آخر التحديثات

$(git log --oneline -5 2>/dev/null || echo "لا يوجد سجل git")

---

*آخر تحديث: $(date)*
PROGRESSEOF

    log "✅ تم تحديث متتبع التقدم"
}

# إنشاء تقرير الحالة
create_status_report() {
    local report_file="${REPO_DIR}/docs/progress/STATUS_REPORT_$(date +%Y%m%d).md"
    
    cat > "$report_file" << 'REPORTEOF'
# 📋 تقرير حالة HyperFFactory
## تاريخ: $(date +"%Y-%m-%d")

## 🎯 الملخص التنفيذي

### الإنجازات الرئيسية هذا الأسبوع:
1. **بناء النظام الإداري الأساسي**
   - العقل المدير المركزي
   - مدير نظام العمليات
   - هيكل قواعد البيانات

2. **التكامل التقني**
   - تحديث الريبو بالكامل
   - توثيق الخطط والاستراتيجيات
   - نظام التحديث الآلي

### المؤشرات الرئيسية:
- ✅ البنية التقنية: 100%
- 🚧 النظام الإداري: 40%
- 🔴 التعلم الذاتي: 0%
- 🔴 الذكاء المتقدم: 0%

## 📊 التقدم التفصيلي

### المكونات المكتملة:
\`\`\`
$(find "$REPO_DIR/src/hyper_factory/management" -name "*.py" -type f 2>/dev/null | xargs -I {} basename {} | sed 's/^/• /' || echo "• لا توجد مكونات بعد")
\`\`\`

### الخطوات القادمة الفورية:
1. إنشاء مدير نظام الجودة
2. بناء واجهات API للإدارة  
3. ربط قواعد البيانات التشغيلية
4. اختبار سيناريوهات الإدارة

## ⚠️ التحديات والحلول

### التحديات الحالية:
- تكامل قواعد البيانات المتنوعة
- اختبار أداء النظام الإداري
- توثيق API بشكل شامل

### الحلول المقترحة:
- استخدام طبقة تجريد للبيانات
- بناء نظام اختبار شامل
- إنشاء توثيق تفاعلي

## 🎯 الأهداف للأسبوع القادم

1. **إكمال النظام الإداري** (60%)
2. **بدء نظام التعلم** (20%) 
3. **توثيق API** (100%)
4. **اختبار التكامل** (50%)

---

*تم إنشاء التقرير تلقائياً*
REPORTEOF

    log "✅ تم إنشاء تقرير الحالة: $(basename "$report_file")"
}

# تحديث ملف README الرئيسي
update_main_readme() {
    local readme_file="${REPO_DIR}/README.md"
    
    # تحديث قسم الحالة في README
    if grep -q "## 📊 حالة المشروع" "$readme_file"; then
        sed -i '/## 📊 حالة المشروع/,/## 🎯/ { /## 🎯/! d }' "$readme_file"
        sed -i '/## 📊 حالة المشروع/ a\
\
### 🟢 الحالة الحالية: نشط وجاهز للتطوير\
• **آخر تحديث**: '"$(date +"%Y-%m-%d %H:%M")"'\
• **الإصدار**: 2.0\
• **المرحلة الحالية**: بناء النظام الإداري\
• **التقدم**: 40%\
\
### 📈 الإحصائيات:\
• الملفات البرمجية: '"$(find "$REPO_DIR" -name "*.py" -type f | wc -l)"'\
• الخدمات النشطة: '"$(docker ps -q | wc -l)"'\
• قواعد البيانات: '"$(find "$REPO_DIR/var/db" -name "*.db" -type f 2>/dev/null | wc -l)"'\
\
### 🔄 آخر التحديثات:\
'"$(git log --oneline -3 --format="• %s (%cr)" 2>/dev/null || echo "• لا يوجد تحديثات")"'\
' "$readme_file"
    fi
    
    log "✅ تم تحديث README.md"
}

# commit و push التحديثات
commit_and_push() {
    local commit_message="$1"
    
    cd "$REPO_DIR"
    
    log "إضافة التغييرات إلى git..."
    git add .
    
    log "إنشاء commit..."
    git commit -m "$commit_message" || {
        warn "لا توجد تغييرات جديدة للـ commit"
        return 0
    }
    
    log "رفع التحديثات إلى الريبو..."
    if git push "$GIT_REMOTE" "$GIT_BRANCH"; then
        log "✅ تم رفع التحديثات بنجاح"
    else
        error "فشل في رفع التحديثات"
        return 1
    fi
}

# الوظيفة الرئيسية
main() {
    local action="${1:-auto}"
    local custom_message="${2:-}"
    
    log "🚀 بدء تشغيل مدير تحديثات HyperFFactory"
    
    # الإعدادات الأولية
    setup_directories
    
    case "$action" in
        "auto")
            auto_update
            ;;
        "manual")
            manual_update "$custom_message"
            ;;
        "status")
            show_status
            ;;
        "backup")
            auto_backup
            ;;
        *)
            error "إجراء غير معروف: $action"
            echo "الاستخدام: $0 [auto|manual|status|backup] [commit_message]"
            return 1
            ;;
    esac
}

# التحديث التلقائي
auto_update() {
    log "🔍 بدء التحديث التلقائي..."
    
    auto_backup
    check_repo_status
    local repo_status=$?
    
    if [ $repo_status -eq 2 ]; then
        update_progress_tracker
        create_status_report
        update_main_readme
        
        local auto_message="🔄 تحديث تلقائي - $(date +'%Y-%m-%d %H:%M')
        
• تحديث متتبع التقدم
• تقرير حالة جديد
• تحديث التوثيق
• نسخة احتياطية تلقائية"
        
        commit_and_push "$auto_message"
    else
        log "✅ لا حاجة لتحديث - الريبو محدث"
    fi
    
    log "🎉 التحديث التلقائي اكتمل"
}

# التحديث اليدوي
manual_update() {
    local message="$1"
    
    if [ -z "$message" ]; then
        error "يجب تقديم رسالة commit للتحديث اليدوي"
        return 1
    fi
    
    log "🔧 بدء التحديث اليدوي..."
    
    auto_backup
    update_progress_tracker
    create_status_report
    update_main_readme
    
    commit_and_push "$message"
    
    log "🎉 التحديث اليدوي اكتمل"
}

# عرض الحالة
show_status() {
    log "📊 عرض حالة المشروع..."
    
    echo
    echo "=========================================="
    echo "🏭 HyperFFactory - حالة المشروع"
    echo "=========================================="
    echo
    
    # حالة الريبو
    cd "$REPO_DIR"
    echo "📁 المسار: $REPO_DIR"
    echo "🌐 الريبو: $(git remote get-url "$GIT_REMOTE" 2>/dev/null || echo 'غير متصل')"
    echo "🎯 الفرع: $(git branch --show-current 2>/dev/null || echo 'غير معروف')"
    echo
    
    # التغييرات الحالية
    local changes=$(git status --porcelain | wc -l)
    if [ "$changes" -gt 0 ]; then
        echo "📝 هناك $changes ملف يحتاج commit:"
        git status --short
    else
        echo "✅ لا توجد تغييرات معلقة"
    fi
    
    echo
    echo "📈 الإحصائيات:"
    echo "• الملفات البرمجية: $(find "$REPO_DIR" -name "*.py" -type f | wc -l)"
    echo "• الخدمات النشطة: $(docker ps -q | wc -l)"
    echo "• قواعد البيانات: $(find "$REPO_DIR/var/db" -name "*.db" -type f 2>/dev/null | wc -l)"
    echo "• آخر commit: $(git log -1 --format="%s (%cr)" 2>/dev/null || echo 'غير متوفر')"
    
    echo
    echo "=========================================="
}

# تشغيل البرنامج
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
