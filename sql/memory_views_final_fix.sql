-- إصلاح نهائي للواجهات بناءً على البيانات الفعلية في events
BEGIN;

-- حذف الواجهات القديمة
DROP VIEW IF EXISTS v_legacy_event_counts;
DROP VIEW IF EXISTS v_legacy_identity_profile;
DROP VIEW IF EXISTS v_legacy_identity_memories;
DROP VIEW IF EXISTS v_legacy_identity_goals;
DROP VIEW IF EXISTS v_legacy_shared_systems;

-- واجهة إحصائيات الأحداث (محدثة)
CREATE VIEW v_legacy_event_counts AS
SELECT 
  event_type,
  COUNT(*) AS count,
  MIN(timestamp) AS first_occurrence,
  MAX(timestamp) AS last_occurrence
FROM events
GROUP BY event_type
ORDER BY count DESC;

-- واجهة ملف التعريف من بيانات الأحداث
CREATE VIEW v_legacy_identity_profile AS
SELECT 
  event_type AS category,
  COUNT(*) AS count,
  MAX(timestamp) AS last_updated
FROM events 
WHERE event_type LIKE 'legacy.identity.%' 
   OR event_type LIKE 'legacy.shared.%'
   OR event_type LIKE 'legacy.memory.%'
GROUP BY event_type
ORDER BY last_updated DESC;

-- واجهة الأنظمة المشتركة من بيانات الأحداث
CREATE VIEW v_legacy_shared_systems AS
SELECT 
  event_type AS system_name,
  COUNT(*) AS event_count,
  MAX(timestamp) AS last_activity
FROM events
WHERE event_type LIKE 'legacy.shared.%'
GROUP BY event_type
ORDER BY last_activity DESC;

-- واجهة الذكريات من بيانات الأحداث
CREATE VIEW v_legacy_identity_memories AS
SELECT 
  id AS memory_id,
  event_type AS memory_type,
  SUBSTR(payload_json, 1, 100) AS content_preview,
  timestamp AS created_at
FROM events
WHERE event_type LIKE '%memory%' OR event_type LIKE '%legacy.identity.memories%'
ORDER BY timestamp DESC
LIMIT 10;

-- واجهة الأهداف من بيانات الأحداث
CREATE VIEW v_legacy_identity_goals AS
SELECT 
  id AS goal_id,
  event_type AS goal_type,
  'Extracted from events' AS description,
  'medium' AS priority,
  'active' AS status,
  timestamp AS created_at
FROM events
WHERE event_type LIKE '%goal%' OR event_type LIKE '%legacy.identity.goals%'
ORDER BY timestamp DESC
LIMIT 5;

COMMIT;
