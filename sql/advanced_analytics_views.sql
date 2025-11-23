-- واجهات تحليلية متقدمة
BEGIN;

-- تحليل المحتوى حسب الطول
DROP VIEW IF EXISTS v_content_length_analysis;
CREATE VIEW v_content_length_analysis AS
SELECT
  source_type,
  COUNT(*) AS doc_count,
  MIN(LENGTH(content)) AS min_length,
  MAX(LENGTH(content)) AS max_length,
  AVG(LENGTH(content)) AS avg_length,
  SUM(LENGTH(content)) AS total_chars
FROM documents
WHERE content IS NOT NULL
GROUP BY source_type;

-- تحليل التوزيع الزمني
DROP VIEW IF EXISTS v_temporal_analysis;
CREATE VIEW v_temporal_analysis AS
SELECT
  source_type,
  COUNT(*) AS doc_count,
  MIN(created_at) AS earliest,
  MAX(created_at) AS latest,
  COUNT(DISTINCT substr(created_at, 1, 10)) AS unique_days
FROM documents
WHERE created_at IS NOT NULL 
  AND created_at != '0000-00-00T00:00:00'
GROUP BY source_type;

COMMIT;
