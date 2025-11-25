#!/usr/bin/env bash
# Stage 6 – HyperFFactory Quality System (مصحح للهيكل الفعلي)
set -euo pipefail

HYPER_ROOT="/root/HyperFFactory"
META_DIR="${HYPER_ROOT}/db/meta"
QUALITY_DB="${META_DIR}/hf_quality.db"
TASKS_DB="${META_DIR}/hf_tasks.db"

TS_HUMAN="$(date '+%Y-%m-%d %H:%M:%S %z')"
TS_SQL="$(date '+%Y-%m-%d %H:%M:%S')"

echo "====================================================="
echo "Stage 6 – HyperFFactory Quality System (hf_quality.db)"
echo "====================================================="
echo "ROOT      : $HYPER_ROOT"
echo "TIMESTAMP : $TS_HUMAN"
echo

# 1) جمع إحصائيات المهام من hf_tasks.db
if [[ -f "$TASKS_DB" ]]; then
    echo "1) جمع مؤشرات الجودة من hf_tasks.db"
    
    TOTAL_TASKS=$(sqlite3 "$TASKS_DB" "SELECT COUNT(*) FROM tasks;" 2>/dev/null || echo "0")
    DONE_TASKS=$(sqlite3 "$TASKS_DB" "SELECT COUNT(*) FROM tasks WHERE status='DONE';" 2>/dev/null || echo "0")
    PLANNED_TASKS=$(sqlite3 "$TASKS_DB" "SELECT COUNT(*) FROM tasks WHERE status='PLANNED';" 2>/dev/null || echo "0")
    
    # حساب النسبة المئوية
    if [[ $TOTAL_TASKS -gt 0 ]]; then
        DONE_RATIO=$(( (DONE_TASKS * 100) / TOTAL_TASKS ))
    else
        DONE_RATIO=0
    fi
    
    echo "   - إجمالي المهام: $TOTAL_TASKS"
    echo "   - المهام المكتملة: $DONE_TASKS"
    echo "   - المهام المخططة: $PLANNED_TASKS"
    echo "   - نسبة الإنجاز: $DONE_RATIO%"
    
    # 2) إدخال البيانات في quality_runs (باستخدام الأعمدة الصحيحة حسب الهيكل الفعلي)
    sqlite3 "$QUALITY_DB" <<SQL
    -- إضافة مؤشرات الجودة الأساسية إذا لم تكن موجودة
    INSERT OR IGNORE INTO quality_metrics (metric_code, name, description, target_value, unit, is_active)
    VALUES 
    ('tasks_total', 'إجمالي المهام', 'عدد المهام الكلي في النظام', 10, 'مهمة', 1),
    ('tasks_done', 'المهام المكتملة', 'عدد المهام المنتهية بنجاح', 10, 'مهمة', 1),
    ('tasks_planned', 'المهام المخططة', 'عدد المهام في حالة الانتظار', 0, 'مهمة', 1),
    ('tasks_done_ratio', 'نسبة الإنجاز', 'النسبة المئوية للمهام المكتملة', 100, 'نسبة', 1);
    
    -- تسجيل تشغيل الجودة
    INSERT INTO quality_runs (check_code, target, status, details, started_at, finished_at)
    VALUES 
    ('tasks_snapshot', 'hf_tasks.db', 'OK', 'فحص إحصاءات المهام', '$TS_SQL', '$TS_SQL');
    
    -- تحديث quality_metrics بالقيم الحالية
    UPDATE quality_metrics SET 
        target_value = CASE 
            WHEN metric_code = 'tasks_total' THEN $TOTAL_TASKS
            WHEN metric_code = 'tasks_done' THEN $DONE_TASKS  
            WHEN metric_code = 'tasks_planned' THEN $PLANNED_TASKS
            WHEN metric_code = 'tasks_done_ratio' THEN $DONE_RATIO
            ELSE target_value
        END,
        updated_at = '$TS_SQL'
    WHERE metric_code IN ('tasks_total', 'tasks_done', 'tasks_planned', 'tasks_done_ratio');
SQL
    
    echo "✅ تم تسجيل مؤشرات الجودة في hf_quality.db"
else
    echo "⚠️ لا يوجد $TASKS_DB - تم تخطي جمع مؤشرات المهام"
fi

echo
echo "✅ Stage 6 مكتمل"
