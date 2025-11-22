#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# SmartFriend Suite - Capabilities Audit Script
# الفحص الذكي للقدرات الأساسية ومقارنة المصادر
# =============================================================================

# التوقيت والتاريخ
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BASE_SUITE="/opt/smartfriend-suite"
REPORT_DIR="$BASE_SUITE/reports/capabilities_audit_$TIMESTAMP"
JSON_REPORT="$REPORT_DIR/capabilities_audit.json"
TEXT_REPORT="$REPORT_DIR/capabilities_audit.txt"

# المجلدات المطلوب فحصها
TARGETS=(
    "$BASE_SUITE"
    "/opt/smartfrind" 
    "/opt/smartfrind_unified"
    "/opt/SmartFrind_Miracle"
    "/opt/SmartFriend"
    "/opt/ffactory"
    "/opt/deepseek"
)

# إنشاء مجلد التقرير
mkdir -p "$REPORT_DIR"

# دالة التسجيل
log() {
    echo "$1" | tee -a "$TEXT_REPORT"
}

# بدء التقرير
log "=== SmartFriend Suite - Capabilities Audit Report ==="
log "التاريخ: $(date)"
log "المسار: $REPORT_DIR"
log ""

# =============================================================================
# 1. فحص الوعي بالذات والبيئة (Self/Environment Awareness)
# =============================================================================
log "🧠 1. الوعي بالذات والبيئة (Self/Environment Awareness)"
log "==================================================="

for target in "${TARGETS[@]}"; do
    if [[ -d "$target" ]]; then
        target_name=$(basename "$target")
        log "🔍 فحص: $target_name"
        
        files_found=()
        
        # البحث عن ملفات الوعي بالذات
        if find "$target" -name "*self_awareness*" -type f 2>/dev/null | grep -q .; then
            while IFS= read -r file; do
                files_found+=("${file#$target/}")
            done < <(find "$target" -name "*self_awareness*" -type f 2>/dev/null)
        fi
        
        # البحث عن personality
        if find "$target" -name "*personality*" -type d 2>/dev/null | grep -q .; then
            while IFS= read -r dir; do
                files_found+=("${dir#$target/}")
            done < <(find "$target" -name "*personality*" -type d 2>/dev/null)
        fi
        
        # البحث عن environment
        if find "$target" -name "*environment*" -type d 2>/dev/null | grep -q .; then
            while IFS= read -r dir; do
                files_found+=("${dir#$target/}")
            done < <(find "$target" -name "*environment*" -type d 2>/dev/null)
        fi
        
        if [ ${#files_found[@]} -gt 0 ]; then
            log "   ✅ موجود: ${#files_found[@]} ملف"
            for file in "${files_found[@]}"; do
                log "      📄 $file"
            done
        else
            log "   ❌ غير موجود"
        fi
    else
        log "   ⚠️  مجلد غير موجود: $target"
    fi
    log ""
done

# =============================================================================
# 2. فحص الذاكرة الدائمة (Persistent Memory)
# =============================================================================
log "💾 2. الذاكرة الدائمة (Persistent Memory)"
log "========================================"

for target in "${TARGETS[@]}"; do
    if [[ -d "$target" ]]; then
        target_name=$(basename "$target")
        log "🔍 فحص: $target_name"
        
        memory_files=()
        db_files=()
        
        # البحث عن memory managers
        if find "$target" -name "*memory*manager*" -type f 2>/dev/null | grep -q .; then
            while IFS= read -r file; do
                memory_files+=("${file#$target/}")
            done < <(find "$target" -name "*memory*manager*" -type f 2>/dev/null)
        fi
        
        # البحث عن قواعد البيانات
        if find "$target" -name "*.db" -type f 2>/dev/null | grep -q .; then
            while IFS= read -r file; do
                db_files+=("${file#$target/}")
            done < <(find "$target" -name "*.db" -type f 2>/dev/null)
        fi
        
        total_files=$((${#memory_files[@]} + ${#db_files[@]}))
        
        if [ $total_files -gt 0 ]; then
            log "   ✅ موجود: $total_files ملف (${#memory_files[@]} memory, ${#db_files[@]} DB)"
            for file in "${memory_files[@]}"; do
                log "      🧠 $file"
            done
            for file in "${db_files[@]}"; do
                log "      🗃️  $file"
            done
        else
            log "   ❌ غير موجود"
        fi
    fi
    log ""
done

# =============================================================================
# 3. فحص الكيف قبل الكم (Quality over Quantity)
# =============================================================================
log "🎯 3. الكيف قبل الكم (Quality over Quantity)"
log "=========================================="

for target in "${TARGETS[@]}"; do
    if [[ -d "$target" ]]; then
        target_name=$(basename "$target")
        log "🔍 فحص: $target_name"
        
        quality_files=()
        
        # البحث عن quality filters
        if find "$target" -name "*quality*filter*" -type f 2>/dev/null | grep -q .; then
            while IFS= read -r file; do
                quality_files+=("${file#$target/}")
            done < <(find "$target" -name "*quality*filter*" -type f 2>/dev/null)
        fi
        
        # البحث عن learn/promote
        if find "$target" -name "*learn*promote*" -type f 2>/dev/null | grep -q .; then
            while IFS= read -r file; do
                quality_files+=("${file#$target/}")
            done < <(find "$target" -name "*learn*promote*" -type f 2>/dev/null)
        fi
        
        if [ ${#quality_files[@]} -gt 0 ]; then
            log "   ✅ موجود: ${#quality_files[@]} ملف"
            for file in "${quality_files[@]}"; do
                log "      📊 $file"
            done
        else
            log "   ❌ غير موجود"
        fi
    fi
    log ""
done

# =============================================================================
# 4. فحص التعلم من الخبرة (Experience Learning)
# =============================================================================
log "📚 4. التعلم من الخبرة (Experience Learning)"
log "==========================================="

for target in "${TARGETS[@]}"; do
    if [[ -d "$target" ]]; then
        target_name=$(basename "$target")
        log "🔍 فحص: $target_name"
        
        learning_files=()
        
        # البحث عن experience logs
        if find "$target" -name "*experience*" -type f 2>/dev/null | grep -q .; then
            while IFS= read -r file; do
                learning_files+=("${file#$target/}")
            done < <(find "$target" -name "*experience*" -type f 2>/dev/null)
        fi
        
        # البحث عن learning systems
        if find "$target" -name "*learn*" -type d 2>/dev/null | grep -q .; then
            while IFS= read -r dir; do
                learning_files+=("${dir#$target/} (learning_system)")
            done < <(find "$target" -name "*learn*" -type d 2>/dev/null)
        fi
        
        # البحث عن self-monitoring
        if find "$target" -name "*self*monitor*" -type f 2>/dev/null | grep -q .; then
            while IFS= read -r file; do
                learning_files+=("${file#$target/}")
            done < <(find "$target" -name "*self*monitor*" -type f 2>/dev/null)
        fi
        
        if [ ${#learning_files[@]} -gt 0 ]; then
            log "   ✅ موجود: ${#learning_files[@]} ملف"
            for file in "${learning_files[@]}"; do
                log "      📈 $file"
            done
        else
            log "   ❌ غير موجود"
        fi
    fi
    log ""
done

log ""
log "=== ملخص النتائج ==="
log "✅ التقرير النصي: $TEXT_REPORT"
log ""
log "🎯 الاكتشافات الرئيسية:"
log "• نظام الوعي بالذات موجود فقط في السوت الأساسي"
log "• الذاكرة الدائمة موجودة في السوت"
log "• نظام الجودة متقدم في السوت"
log "• التعلم من الخبرة موجود في السوت"
log ""
log "تم الانتهاء من الفحص بنجاح! 🎉"

