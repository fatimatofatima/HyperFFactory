-- تقرير شامل عن الهجرة
.headers on
.mode column

-- تقرير المعرفة
SELECT '=== KNOWLEDGE MIGRATION REPORT ===' AS report_section;
SELECT 
  'Total Documents' AS metric,
  COUNT(*) AS value 
FROM documents
UNION ALL
SELECT 
  'Unique Content Hashes' AS metric,
  COUNT(DISTINCT content_hash) AS value 
FROM documents
UNION ALL
SELECT 
  'Documents with Content' AS metric,
  COUNT(*) AS value 
FROM documents 
WHERE content IS NOT NULL AND LENGTH(content) > 0;

SELECT '=== Documents by Source Type ===' AS report_section;
SELECT * FROM v_knowledge_documents_by_source_type;

-- تقرير الذاكرة
SELECT '=== MEMORY MIGRATION REPORT ===' AS report_section;
SELECT 
  'Total Legacy Events' AS metric,
  COUNT(*) AS value 
FROM events 
WHERE event_type LIKE 'legacy.%'
UNION ALL
SELECT 
  'Unique Correlation IDs' AS metric,
  COUNT(DISTINCT correlation_id) AS value 
FROM events 
WHERE event_type LIKE 'legacy.%';

SELECT '=== Legacy Events by Type ===' AS report_section;
SELECT * FROM v_legacy_event_counts;

-- تقرير الهوية
SELECT '=== IDENTITY MIGRATION REPORT ===' AS report_section;
SELECT 
  'Memories' AS category,
  COUNT(*) AS count 
FROM v_legacy_identity_memories
UNION ALL
SELECT 
  'Goals' AS category,
  COUNT(*) AS count 
FROM v_legacy_identity_goals
UNION ALL
SELECT 
  'Profile Items' AS category,
  COUNT(*) AS count 
FROM v_legacy_identity_profile;
