-- واجهات أساسية للمعرفة
BEGIN;

DROP VIEW IF EXISTS v_knowledge_documents_core;
DROP VIEW IF EXISTS v_knowledge_documents_by_source_type;
DROP VIEW IF EXISTS v_knowledge_documents_recent;

CREATE VIEW v_knowledge_documents_core AS
SELECT
  id,
  source_type,
  title,
  content,
  content_hash,
  created_at,
  indexed_at
FROM documents
WHERE content IS NOT NULL;

CREATE VIEW v_knowledge_documents_by_source_type AS
SELECT
  source_type,
  COUNT(*) AS document_count,
  AVG(LENGTH(content)) AS avg_content_length,
  MIN(created_at) AS oldest_document,
  MAX(created_at) AS newest_document
FROM documents
GROUP BY source_type;

CREATE VIEW v_knowledge_documents_recent AS
SELECT *
FROM documents
WHERE created_at >= datetime('now', '-7 days')
ORDER BY created_at DESC;

COMMIT;
