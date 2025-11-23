-- واجهات أساسية للذاكرة
BEGIN;

DROP VIEW IF EXISTS v_legacy_event_counts;
DROP VIEW IF EXISTS v_legacy_identity_profile;
DROP VIEW IF EXISTS v_legacy_identity_memories;
DROP VIEW IF EXISTS v_legacy_identity_goals;

CREATE VIEW v_legacy_event_counts AS
SELECT 
  event_type,
  COUNT(*) AS count,
  MIN(timestamp) AS first_occurrence,
  MAX(timestamp) AS last_occurrence
FROM events
GROUP BY event_type;

CREATE VIEW v_legacy_identity_profile AS
SELECT 
  'systems' AS category, 
  COUNT(*) AS count 
FROM systems
UNION ALL
SELECT 
  'profile_items' AS category, 
  COUNT(*) AS count 
FROM profile_items
UNION ALL
SELECT 
  'memories' AS category, 
  COUNT(*) AS count 
FROM memories
UNION ALL
SELECT 
  'goals' AS category, 
  COUNT(*) AS count 
FROM goals;

CREATE VIEW v_legacy_identity_memories AS
SELECT 
  memory_id,
  memory_type,
  SUBSTR(content, 1, 100) AS content_preview,
  created_at
FROM memories
ORDER BY created_at DESC
LIMIT 10;

CREATE VIEW v_legacy_identity_goals AS
SELECT 
  goal_id,
  goal_type,
  SUBSTR(description, 1, 100) AS description_preview,
  priority,
  status
FROM goals
ORDER BY priority DESC, created_at DESC;

COMMIT;
