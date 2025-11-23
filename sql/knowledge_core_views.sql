BEGIN;

-- إسقاط الواجهات القديمة إن وُجدت (اختياري آمن)
DROP VIEW IF EXISTS v_knowledge_documents_core;
DROP VIEW IF EXISTS v_knowledge_documents_by_source_type;
DROP VIEW IF EXISTS v_knowledge_documents_recent;

-- واجهة أساسية للوثائق
CREATE VIEW IF NOT EXISTS v_knowledge_documents_core AS
SELECT
  id,
  source_type,
  title,
  content,
  content_hash,
  created_at
FROM documents;

-- تجميع حسب نوع المصدر
CREATE VIEW IF NOT EXISTS v_knowledge_documents_by_source_type AS
SELECT
  source_type,
  COUNT(*) AS doc_count
FROM documents
GROUP BY source_type
ORDER BY doc_count DESC;

-- أحدث الوثائق + ملخّص نصي
CREATE VIEW IF NOT EXISTS v_knowledge_documents_recent AS
SELECT
  id,
  source_type,
  title,
  substr(content, 1, 400) AS snippet,
  created_at
FROM documents
ORDER BY
  COALESCE(created_at, '0000-00-00T00:00:00') DESC,
  id DESC;

COMMIT;
