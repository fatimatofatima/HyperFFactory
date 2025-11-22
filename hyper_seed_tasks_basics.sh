#!/usr/bin/env bash
set -euo pipefail

TASK_DB="/opt/hyper-factory/var/db/tasks/tasks.db"

if [[ ! -f "$TASK_DB" ]]; then
  echo "❌ tasks.db غير موجود: $TASK_DB"
  exit 1
fi

echo "🧱 Seed أساسي للوظائف (job_types + schedules) في: $TASK_DB"

# عرض الجداول للتأكيد
echo "== .tables =="
sqlite3 "$TASK_DB" ".tables" || true
echo

sqlite3 "$TASK_DB" <<'SQL'
PRAGMA journal_mode=WAL;

-- 1) أنواع الوظائف الأساسية (Job Types)
INSERT OR IGNORE INTO job_types (code, name, description, default_priority, created_at) VALUES
  ('FACTORY_SCAN_BACKUPS',      'Scan legacy backups',      'فحص أرشيف النسخ الاحتياطية وتصنيف قواعد البيانات',                     5, datetime('now')),
  ('FACTORY_DEDUP_ROOT',        'Root deduplication',       'حذف الملفات المكررة (hash-based) من مسارات محددة',                       4, datetime('now')),
  ('FACTORY_BUILD_SERVICE_MAP', 'Build service matrix',     'بناء خريطة الخدمات (systemd/docker) وربطها بالمشروعات',                 5, datetime('now')),
  ('FACTORY_ANALYZE_DBS',       'Analyze legacy databases', 'تحليل قواعد البيانات القديمة وتحديث hyper_meta.db / memory_core',       6, datetime('now')),
  ('FACTORY_BACKUP_KNOWLEDGE',  'Backup knowledge DB',      'نسخ احتياطي آمن لقواعد المعرفة knowledge_* إلى مسار مخصص',              3, datetime('now')),
  ('FACTORY_CLEAN_TMP',         'Clean temp + WAL',         'تنظيف الملفات المؤقتة والـ WAL للحد من استهلاك الديسك',                  4, datetime('now')),
  ('FACTORY_HEALTH_CHECK',      'Factory health check',     'فحص الحالة العامة للسيرفر والخدمات وتسجيل النتائج في memory_core',      5, datetime('now'));

-- 2) جداول تشغيل دورية (Schedules) – تعريف فقط (من غير تنفيذ فعلي)
INSERT OR IGNORE INTO schedules (
    job_type_id,
    schedule_code,
    cron_expr,
    enabled,
    last_run_at,
    next_run_at,
    config_json,
    created_at
)
SELECT
  jt.id,
  sc.code,
  sc.cron_expr,
  1 AS enabled,
  NULL AS last_run_at,
  NULL AS next_run_at,
  sc.config_json,
  datetime('now')
FROM job_types jt
JOIN (
  -- Backup المعرفة يوميًا الساعة 02:00
  SELECT
    'FACTORY_BACKUP_KNOWLEDGE' AS job_type_code,
    'DAILY_02_KNOWLEDGE_BACKUP' AS code,
    '0 2 * * *' AS cron_expr,
    json_object('target', '/root/HyperFFactory/knowledge_backups') AS config_json
  UNION ALL
  -- Scan قواعد البيانات / الميتا يوميًا الساعة 03:00
  SELECT
    'FACTORY_ANALYZE_DBS',
    'DAILY_03_DB_ANALYZE',
    '0 3 * * *',
    json_object('source', '/root/HyperFFactory/all_legacy_dbs')
  UNION ALL
  -- Health Check كل ساعة
  SELECT
    'FACTORY_HEALTH_CHECK',
    'HOURLY_FACTORY_HEALTH',
    '0 * * * *',
    json_object('scope', 'system')
  UNION ALL
  -- تنظيف TMP + WAL مرتين في اليوم
  SELECT
    'FACTORY_CLEAN_TMP',
    'TWICE_DAILY_CLEAN_TMP',
    '0 4,16 * * *',
    json_object('paths', json('["/tmp","/root/HyperFFactory/tmp"]'))
) sc
ON jt.code = sc.job_type_code
WHERE NOT EXISTS (
  SELECT 1 FROM schedules s WHERE s.schedule_code = sc.code
);
SQL

echo "✅ Seed الوظائف الأساسية تم."

echo
echo "== job_types =="
sqlite3 "$TASK_DB" "SELECT id, code, name, default_priority FROM job_types ORDER BY id;"

echo
echo "== schedules =="
sqlite3 "$TASK_DB" "SELECT id, schedule_code, cron_expr FROM schedules ORDER BY id;"
