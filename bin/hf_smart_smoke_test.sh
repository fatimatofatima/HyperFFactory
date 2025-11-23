#!/usr/bin/env bash
set -euo pipefail

ROOT="/root/HyperFFactory"
cd "$ROOT"

LOG_DIR="$ROOT/reports"
mkdir -p "$LOG_DIR"
TS=$(date '+%Y%m%d_%H%M%S')
LOG_FILE="$LOG_DIR/hf_smart_smoke_${TS}.log"

echo "🧪 HYPERFFACTORY SMART SMOKE TEST"
echo "🕐 $(date '+%Y-%m-%d %H:%M:%S')"
echo "📂 Root: $ROOT"
echo "📝 Log: $LOG_FILE"
echo "=========================================="

{
echo "🧪 HYPERFFACTORY SMART SMOKE TEST - $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="

FAILURES=0
WARNINGS=0
CRITICAL_GAPS=0

log_result() {
    local level="$1"
    local message="$2"
    case "$level" in
        "CRITICAL") 
            echo "🔴 CRITICAL: $message"
            ((CRITICAL_GAPS++))
            ;;
        "FAILURE") 
            echo "❌ FAILURE: $message" 
            ((FAILURES++))
            ;;
        "WARNING") 
            echo "⚠️  WARNING: $message"
            ((WARNINGS++))
            ;;
        "SUCCESS") 
            echo "✅ SUCCESS: $message" 
            ;;
        "INFO") 
            echo "ℹ️  INFO: $message" 
            ;;
    esac
}

check_service_health() {
    echo
    echo "🔍 [1/6] فحص صحة الخدمات والتبعيات"
    echo "----------------------------------------"
    
    # SmartFriend services
    local sf_services=("sf-core" "sf-bot" "sf-web" "sf-health" "sf-memory")
    for service in "${sf_services[@]}"; do
        if systemctl is-active "$service" >/dev/null 2>&1; then
            local status=$(systemctl is-active "$service")
            if [[ "$status" == "active" ]]; then
                log_result "SUCCESS" "Service $service: $status"
            else
                log_result "WARNING" "Service $service: $status (should be active)"
            fi
        else
            log_result "FAILURE" "Service $service: NOT FOUND or INACTIVE"
        fi
    done

    # Check for legacy services that should NOT exist
    if systemctl list-units | grep -q "smartfrind-"; then
        log_result "CRITICAL" "Legacy smartfrind-* services found - CONFLICT RISK"
    else
        log_result "SUCCESS" "No legacy smartfrind-* services"
    fi

    # FFactory containers
    local container_count=$(docker ps --filter "name=ffactory" --format "{{.Names}}" | wc -l)
    if [[ $container_count -gt 0 ]]; then
        log_result "SUCCESS" "FFactory containers: $container_count running"
    else
        log_result "FAILURE" "No FFactory containers running"
    fi
}

check_unified_tree_integrity() {
    echo
    echo "🔍 [2/6] فحص نزاهة الشجرة الموحدة"
    echo "----------------------------------------"
    
    # Check internal opt directory
    if [[ -d "$ROOT/opt" ]]; then
        log_result "SUCCESS" "Internal /opt exists and is part of unified tree"
    else
        log_result "FAILURE" "Internal /opt directory missing"
    fi

    # Check integration points
    local integration_points=("/opt/smartfriend-suite" "/opt/ffactory")
    for point in "${integration_points[@]}"; do
        if [[ -d "$point" ]]; then
            log_result "SUCCESS" "Integration point $point exists"
        else
            log_result "FAILURE" "Integration point $point missing"
        fi
    done

    # Check for escape pointers (symlinks/hardlinks outside tree)
    local escape_links=$(find "$ROOT" -type l -exec ls -la {} \; 2>/dev/null | grep -E "\s+/(opt|usr|var|etc|root)" || true)
    if [[ -n "$escape_links" ]]; then
        log_result "CRITICAL" "Found escape pointers (symlinks outside tree):"
        echo "$escape_links" | while read link; do
            log_result "CRITICAL" "   $link"
        done
    else
        log_result "SUCCESS" "No escape pointers detected"
    fi
}

check_system_connectivity() {
    echo
    echo "🔍 [3/6] فحص الربطية والاتصالات"
    echo "----------------------------------------"
    
    # Database connectivity
    if [[ -f "/opt/smartfriend-suite/var/db/smartfriend_unified.db" ]]; then
        if sqlite3 "/opt/smartfriend-suite/var/db/smartfriend_unified.db" "SELECT 1;" >/dev/null 2>&1; then
            log_result "SUCCESS" "SmartFriend database: accessible and responsive"
        else
            log_result "FAILURE" "SmartFriend database: inaccessible or corrupted"
        fi
    else
        log_result "WARNING" "SmartFriend database: file not found"
    fi

    # Check HyperFFactory databases
    local hf_dbs=("db/meta/hf_changes.db" "db/meta/hf_tasks.db" "db/meta/hf_quality.db" "db/meta/hf_errors.db")
    for db in "${hf_dbs[@]}"; do
        if [[ -f "$db" ]]; then
            log_result "SUCCESS" "HyperFFactory DB: $db exists"
        else
            log_result "WARNING" "HyperFFactory DB: $db missing (may be normal if not used yet)"
        fi
    done

    # Check report generation capability
    if bin/hf_health_all.sh > /tmp/hf_health_test.log 2>&1; then
        log_result "SUCCESS" "Health report generation: functional"
        # Check if report contains critical information
        if grep -q "HEALTH CHECK" /tmp/hf_health_test.log; then
            log_result "SUCCESS" "Health report content: valid"
        else
            log_result "WARNING" "Health report content: may be incomplete"
        fi
    else
        log_result "FAILURE" "Health report generation: failed"
    fi
    rm -f /tmp/hf_health_test.log
}

check_operational_gaps() {
    echo
    echo "🔍 [4/6] كشف الفجوات التشغيلية"
    echo "----------------------------------------"
    
    # Check for mandatory logging compliance
    local recent_reports=$(find "$LOG_DIR" -name "*.log" -mtime -1 | wc -l)
    if [[ $recent_reports -gt 0 ]]; then
        log_result "SUCCESS" "Logging activity: $recent_reports reports in last 24h"
    else
        log_result "WARNING" "Logging activity: No recent reports - possible compliance issue"
    fi

    # Check cron automation
    local cron_entries=$(crontab -l 2>/dev/null | grep -c "HyperFFactory\|hf_" || true)
    if [[ $cron_entries -gt 0 ]]; then
        log_result "SUCCESS" "Automation: $cron_entries cron entries found"
    else
        log_result "WARNING" "Automation: No cron entries - manual operation only"
    fi

    # Check backup policies
    local backup_scripts=$(find bin -name "*backup*" -o -name "*snapshot*" | wc -l)
    if [[ $backup_scripts -gt 0 ]]; then
        log_result "SUCCESS" "Backup: Scripts exist ($backup_scripts found)"
    else
        log_result "WARNING" "Backup: No backup scripts found"
    fi

    # Check for integration APIs
    if curl --max-time 5 -s http://localhost:8000/health >/dev/null 2>&1 \
       || curl --max-time 5 -s http://localhost:3000/health >/dev/null 2>&1; then
        log_result "SUCCESS" "Integration APIs: Some endpoints responsive"
    else
        log_result "WARNING" "Integration APIs: No responsive endpoints found"
    fi
}

check_four_systems_integration() {
    echo
    echo "🔍 [5/6] فحص تكامل الأنظمة الأربعة"
    echo "----------------------------------------"
    
    local systems=("Tasks" "Quality" "Experience" "Errors")
    local system_dbs=("hf_tasks.db" "hf_quality.db" "hf_learning.db" "hf_errors.db")
    
    for i in "${!systems[@]}"; do
        local system="${systems[$i]}"
        local db="${system_dbs[$i]}"
        
        if [[ -f "db/meta/$db" ]]; then
            local table_count=$(sqlite3 "db/meta/$db" ".tables" 2>/dev/null | wc -l || echo "0")
            if [[ $table_count -gt 0 ]]; then
                log_result "SUCCESS" "System $system: Database active ($table_count tables)"
            else
                log_result "WARNING" "System $system: Database exists but empty"
            fi
        else
            log_result "WARNING" "System $system: Database not found"
        fi
    done

    # Check cross-system relationships
    if [[ -f "db/meta/hf_changes.db" ]]; then
        local change_count=$(sqlite3 "db/meta/hf_changes.db" "SELECT COUNT(*) FROM changes;" 2>/dev/null || echo "0")
        if [[ $change_count -gt 0 ]]; then
            log_result "SUCCESS" "Change tracking: $change_count records found"
        else
            log_result "WARNING" "Change tracking: No records found"
        fi
    fi
}

check_policy_compliance() {
    echo
    echo "🔍 [6/6] فحص التوافق مع السياسات"
    echo "----------------------------------------"
    
    # Check unified tree policy enforcement
    if [[ -x "bin/hf_assert_unified_tree.sh" ]]; then
        if bin/hf_assert_unified_tree.sh > /tmp/tree_check.log 2>&1; then
            log_result "SUCCESS" "Tree policy: Enforcement script functional"
        else
            local violations=$(grep -c "VIOLATION\|ESCAPE" /tmp/tree_check.log || echo "0")
            if [[ $violations -gt 0 ]]; then
                log_result "CRITICAL" "Tree policy: $violations violations detected"
            else
                log_result "WARNING" "Tree policy: Script reported issues"
            fi
        fi
        rm -f /tmp/tree_check.log
    else
        log_result "FAILURE" "Tree policy: Enforcement script missing/not executable"
    fi

    # Check progress logging compliance
    local recent_activities=$(find . -name "*.sh" -exec grep -l "reports/\|hf_changes.db" {} \; | wc -l)
    if [[ $recent_activities -gt 5 ]]; then
        log_result "SUCCESS" "Progress logging: $recent_activities scripts compliant"
    else
        log_result "WARNING" "Progress logging: Limited compliance detected"
    fi

    # Check data preservation policy
    if [[ -d "reports" && -d "db/meta" ]]; then
        local total_reports=$(find reports -name "*.log" -type f | wc -l)
        local total_db_files=$(find db/meta -name "*.db" -type f | wc -l)
        log_result "SUCCESS" "Data preservation: $total_reports reports, $total_db_files databases"
    else
        log_result "WARNING" "Data preservation: Archive structure incomplete"
    fi
}

# Run all checks
check_service_health
check_unified_tree_integrity  
check_system_connectivity
check_operational_gaps
check_four_systems_integration
check_policy_compliance

# Summary
echo
echo "=========================================="
echo "📊 SMART SMOKE TEST SUMMARY"
echo "=========================================="
echo "🔴 Critical Gaps: $CRITICAL_GAPS"
echo "❌ Failures: $FAILURES" 
echo "⚠️  Warnings: $WARNINGS"
echo "------------------------------------------"

if [[ $CRITICAL_GAPS -gt 0 ]]; then
    log_result "CRITICAL" "SYSTEM HAS CRITICAL GAPS REQUIRING IMMEDIATE ATTENTION"
elif [[ $FAILURES -gt 0 ]]; then
    log_result "FAILURE" "System has operational failures needing resolution"
elif [[ $WARNINGS -gt 0 ]]; then
    log_result "WARNING" "System operational but has warnings for improvement"
else
    log_result "SUCCESS" "All systems operational - no critical issues found"
fi

echo "📝 Full details: $LOG_FILE"
echo "🧭 Next: Review gaps and implement fixes"

} | tee "$LOG_FILE"

# Make executable
chmod +x "$0"

echo
echo "🧪 Smart smoke test completed!"
echo "📊 Check $LOG_FILE for detailed analysis"
