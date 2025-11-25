#!/usr/bin/env bash
# Stage 7 – HyperFFactory Learning System (مصحح للهيكل الفعلي)
set -euo pipefail

HYPER_ROOT="/root/HyperFFactory"
META_DIR="${HYPER_ROOT}/db/meta"
LEARNING_DB="${META_DIR}/hf_learning.db"
TASKS_DB="${META_DIR}/hf_tasks.db"

TS_HUMAN="$(date '+%Y-%m-%d %H:%M:%S %z')"
TS_SQL="$(date '+%Y-%m-%d %H:%M:%S')"

echo "====================================================="
echo "Stage 7 – HyperFFactory Learning System (hf_learning.db)"
echo "====================================================="
echo "ROOT      : $HYPER_ROOT"
echo "TIMESTAMP : $TS_HUMAN"
echo

# 1) إشارات تعلّم من مهام HyperFFactory
if [[ -f "$TASKS_DB" ]]; then
    echo "1) إشارات تعلّم من hf_tasks.db"
    
    # جمع إحصائيات المهام
    TOTAL_TASKS=$(sqlite3 "$TASKS_DB" "SELECT COUNT(*) FROM tasks;" 2>/dev/null || echo "0")
    DONE_TASKS=$(sqlite3 "$TASKS_DB" "SELECT COUNT(*) FROM tasks WHERE status='DONE';" 2>/dev/null || echo "0")
    
    # حساب نسبة النجاح
    if [[ $TOTAL_TASKS -gt 0 ]]; then
        SUCCESS_RATE=$(( (DONE_TASKS * 100) / TOTAL_TASKS ))
    else
        SUCCESS_RATE=0
    fi
    
    echo "   - إجمالي المهام: $TOTAL_TASKS"
    echo "   - المهام المكتملة: $DONE_TASKS"
    echo "   - معدل النجاح: $SUCCESS_RATE%"
    
    # تسجيل إشارات التعلّم
    sqlite3 "$LEARNING_DB" <<SQL
    -- تسجيل حدث تعلّم من نظام المهام
    INSERT INTO learning_events (source, event_type, reference_id, payload, created_at)
    VALUES 
    ('hyper_tasks', 'success_rate', 'stage7_snapshot', 
     '{"total_tasks": $TOTAL_TASKS, "done_tasks": $DONE_TASKS, "success_rate": $SUCCESS_RATE}', 
     '$TS_SQL');
    
    -- تسجيل درس مكتسب
    INSERT OR IGNORE INTO lessons_learned (lesson_code, title, description, impact_area, confidence)
    VALUES 
    ('stage7_tasks_completion', 'إكمال المهام الأساسية', 
     'تم إكمال جميع المهام الأساسية لنظام HyperFFactory', 
     'operations', 0.95);
SQL
    
    echo "✅ تم تسجيل إشارات التعلّم في hf_learning.db"
else
    echo "⚠️ لا يوجد $TASKS_DB - تم تخطي إشارات التعلّم من المهام"
fi

echo
echo "✅ Stage 7 مكتمل"
