#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date '+%Y%m%d_%H%M%S')"
REPORT_DIR="/opt/smartfriend-suite/reports"
MATRIX_FILE="$REPORT_DIR/sf_service_matrix_${TS}.csv"

mkdir -p "$REPORT_DIR"

log() { echo "[$(date '+%F %T')] $*"; }

# رأس الملف
{
  echo "Service_Name,Family,Status,Active_State,Port,Role,Description,ExecStart,DB_Used,Config_File,Strength_Score,Action_Plan"
} > "$MATRIX_FILE"

# جمع بيانات كل الخدمات
for prefix in smartfriend- sf- smartfrind-; do
  systemctl list-unit-files "${prefix}*" --no-legend 2>/dev/null | while read -r unit state; do
    [ -z "$unit" ] && continue
    
    # تحديد العائلة
    if [[ "$unit" == sf-* ]]; then
      family="sf"
    elif [[ "$unit" == smartfriend-* ]]; then
      family="smartfriend" 
    elif [[ "$unit" == smartfrind-* ]]; then
      family="smartfrind"
    else
      family="other"
    fi

    # جمع البيانات
    desc=$(systemctl show "$unit" -p Description --value 2>/dev/null || echo "N/A")
    active_state=$(systemctl show "$unit" -p ActiveState --value 2>/dev/null || echo "unknown")
    exec_start=$(systemctl show "$unit" -p ExecStart --value 2>/dev/null || echo "N/A")
    
    # تحديد البورت
    port="N/A"
    if [[ "$exec_start" =~ :([0-9]+) ]]; then
      port="${BASH_REMATCH[1]}"
    fi
    
    # تحديد الدور
    role="other"
    unit_lower=$(echo "$unit" | tr '[:upper:]' '[:lower:]')
    case "$unit_lower" in
      *gateway*|*api*) role="gateway" ;;
      *memory*) role="memory" ;;
      *brain*|*learn*|*kb*|*train*) role="brain" ;;
      *spider*|*harvest*|*ingest*) role="spider" ;;
      *bot*|*telegram*) role="bot" ;;
      *web*|*ui*|*dashboard*) role="web" ;;
      *health*|*guard*|*watchdog*) role="health" ;;
      *factory*) role="factory" ;;
    esac
    
    # تقييم القوة (بناء على الحالة والنشاط)
    strength=0
    if [[ "$active_state" == "active" ]]; then
      strength=$((strength + 3))
    fi
    if [[ "$state" == "enabled" ]]; then
      strength=$((strength + 2))
    fi
    if [[ "$exec_start" != "N/A" ]]; then
      strength=$((strength + 1))
    fi
    
    # خطة العمل المقترحة
    action="KEEP"
    if [[ "$family" == "smartfrind" && "$strength" -lt 3 ]]; then
      action="REPLACE"
    elif [[ "$family" == "smartfrind" && "$strength" -ge 3 ]]; then
      action="MIGRATE_LOGIC"
    fi
    
    # كتابة السجل
    echo "\"$unit\",\"$family\",\"$state\",\"$active_state\",\"$port\",\"$role\",\"$desc\",\"$exec_start\",\"N/A\",\"N/A\",\"$strength\",\"$action\"" >> "$MATRIX_FILE"
  done
done

log "تم إنشاء مصفوفة الخدمات: $MATRIX_FILE"
