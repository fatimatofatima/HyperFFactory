BEGIN;

-- إسقاط الواجهات القديمة إن وُجدت (اختياري آمن)
DROP VIEW IF EXISTS v_legacy_event_counts;
DROP VIEW IF EXISTS v_legacy_identity_memories;
DROP VIEW IF EXISTS v_legacy_identity_goals;
DROP VIEW IF EXISTS v_legacy_identity_profile;
DROP VIEW IF EXISTS v_legacy_shared_systems;

-- إحصائيات الأحداث legacy.*
CREATE VIEW IF NOT EXISTS v_legacy_event_counts AS
SELECT
  event_type,
  COUNT(*) AS event_count
FROM events
WHERE event_type LIKE 'legacy.%'
GROUP BY event_type
ORDER BY event_count DESC;

-- ذكريات الهوية (identity.memories)
CREATE VIEW IF NOT EXISTS v_legacy_identity_memories AS
SELECT
  e.id        AS event_id,
  e.timestamp AS event_ts,
  json_extract(e.payload_json, '$.source_db_file')            AS source_db_file,
  json_extract(e.payload_json, '$.source_db_path')            AS source_db_path,
  json_extract(e.payload_json, '$.source_row.id')             AS memory_id,
  json_extract(e.payload_json, '$.source_row.memory_type')    AS memory_type,
  json_extract(e.payload_json, '$.source_row.content')        AS content,
  json_extract(e.payload_json, '$.source_row.emotional_weight') AS emotional_weight,
  json_extract(e.payload_json, '$.source_row.created_at')     AS created_at
FROM events e
WHERE e.event_type = 'legacy.identity.memories';

-- الأهداف (identity.goals)
CREATE VIEW IF NOT EXISTS v_legacy_identity_goals AS
SELECT
  e.id        AS event_id,
  e.timestamp AS event_ts,
  json_extract(e.payload_json, '$.source_db_file')        AS source_db_file,
  json_extract(e.payload_json, '$.source_db_path')        AS source_db_path,
  json_extract(e.payload_json, '$.source_row.id')         AS goal_id,
  json_extract(e.payload_json, '$.source_row.goal_text')  AS goal_text,
  json_extract(e.payload_json, '$.source_row.category')   AS category,
  json_extract(e.payload_json, '$.source_row.progress')   AS progress,
  json_extract(e.payload_json, '$.source_row.priority')   AS priority,
  json_extract(e.payload_json, '$.source_row.created_at') AS created_at
FROM events e
WHERE e.event_type = 'legacy.identity.goals';

-- بروفايل الهوية (identity.identity_profile)
CREATE VIEW IF NOT EXISTS v_legacy_identity_profile AS
SELECT
  e.id        AS event_id,
  e.timestamp AS event_ts,
  json_extract(e.payload_json, '$.source_db_file')        AS source_db_file,
  json_extract(e.payload_json, '$.source_db_path')        AS source_db_path,
  json_extract(e.payload_json, '$.source_row.key')        AS key,
  json_extract(e.payload_json, '$.source_row.value')      AS value,
  json_extract(e.payload_json, '$.source_row.category')   AS category,
  json_extract(e.payload_json, '$.source_row.importance') AS importance,
  json_extract(e.payload_json, '$.source_row.created_at') AS created_at,
  json_extract(e.payload_json, '$.source_row.updated_at') AS updated_at
FROM events e
WHERE e.event_type = 'legacy.identity.identity_profile';

-- أنظمة shared (shared.systems)
CREATE VIEW IF NOT EXISTS v_legacy_shared_systems AS
SELECT
  e.id        AS event_id,
  e.timestamp AS event_ts,
  json_extract(e.payload_json, '$.source_db_file')         AS source_db_file,
  json_extract(e.payload_json, '$.source_db_path')         AS source_db_path,
  json_extract(e.payload_json, '$.source_row.name')        AS name,
  json_extract(e.payload_json, '$.source_row.status')      AS status,
  json_extract(e.payload_json, '$.source_row.last_update') AS last_update,
  json_extract(e.payload_json, '$.source_row.data')        AS data
FROM events e
WHERE e.event_type = 'legacy.shared.systems';

COMMIT;
