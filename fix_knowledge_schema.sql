-- إضافة الأعمدة المفقودة إذا لم تكن موجودة
ALTER TABLE documents ADD COLUMN external_source TEXT;
ALTER TABLE documents ADD COLUMN source_metadata TEXT;
ALTER TABLE documents ADD COLUMN content_hash TEXT;
ALTER TABLE documents ADD COLUMN embedding_model TEXT;
ALTER TABLE documents ADD COLUMN chunk_index INTEGER;

-- إنشاء الفهارس
CREATE INDEX IF NOT EXISTS idx_documents_source ON documents(external_source);
CREATE INDEX IF NOT EXISTS idx_documents_content_hash ON documents(content_hash);
CREATE INDEX IF NOT EXISTS idx_documents_embedding_model ON documents(embedding_model);

-- تحديث الجدول chunks إذا كان موجوداً
CREATE TABLE IF NOT EXISTS chunks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    document_id INTEGER,
    chunk_index INTEGER,
    content TEXT,
    content_hash TEXT,
    embedding BLOB,
    embedding_model TEXT,
    token_count INTEGER,
    metadata TEXT,
    created_at TEXT,
    FOREIGN KEY (document_id) REFERENCES documents(id)
);

CREATE INDEX IF NOT EXISTS idx_chunks_document_id ON chunks(document_id);
CREATE INDEX IF NOT EXISTS idx_chunks_content_hash ON chunks(content_hash);
