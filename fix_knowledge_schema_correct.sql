-- إضافة الأعمدة المفقودة إلى جدول documents
ALTER TABLE documents ADD COLUMN external_source TEXT;
ALTER TABLE documents ADD COLUMN source_metadata TEXT;
ALTER TABLE documents ADD COLUMN content_hash TEXT;
ALTER TABLE documents ADD COLUMN embedding_model TEXT;
ALTER TABLE documents ADD COLUMN chunk_index INTEGER DEFAULT 0;
ALTER TABLE documents ADD COLUMN content TEXT;

-- إضافة الأعمدة المفقودة إلى جدول chunks  
ALTER TABLE chunks ADD COLUMN content_hash TEXT;
ALTER TABLE chunks ADD COLUMN embedding_model TEXT;
ALTER TABLE chunks ADD COLUMN embedding BLOB;

-- إنشاء الفهارس المطلوبة
CREATE INDEX IF NOT EXISTS idx_documents_source ON documents(external_source);
CREATE INDEX IF NOT EXISTS idx_documents_content_hash ON documents(content_hash);
CREATE INDEX IF NOT EXISTS idx_chunks_content_hash ON chunks(content_hash);
CREATE INDEX IF NOT EXISTS idx_documents_source_type ON documents(source_type);
