-- إضافة الأعمدة المفقودة
ALTER TABLE db_files ADD COLUMN file_size_mb REAL;
ALTER TABLE db_files ADD COLUMN file_role TEXT;
ALTER TABLE db_files ADD COLUMN tables_list TEXT;

-- تحديث البيانات من الأعمدة القديمة
UPDATE db_files SET file_size_mb = size_mb;
UPDATE db_files SET file_role = role;
UPDATE db_files SET tables_list = '[]' WHERE tables_list IS NULL;

-- إنشاء فهارس جديدة
CREATE INDEX IF NOT EXISTS idx_db_files_file_role ON db_files(file_role);
CREATE INDEX IF NOT EXISTS idx_db_files_file_size ON db_files(file_size_mb);
