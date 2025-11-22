# 🚀 دليل استخدام HyperFFactory المتكامل

## 📊 نظرة عامة على البيانات
- **المعرفة**: 152,053 مستند
- **الذاكرة**: 619 حدث 
- **الهوية**: 110 كيان

## 🔍 استعلامات سريعة

### استعلامات المعرفة
\`\`\`sql
-- أحدث 10 مستندات
SELECT * FROM v_knowledge_documents_recent LIMIT 10;

-- تحليل المحتوى حسب المصدر
SELECT * FROM v_knowledge_documents_by_source_type;

-- البحث في المحتوى
SELECT id, title, substr(content, 1, 100) AS preview 
FROM documents 
WHERE content LIKE '%python%' 
LIMIT 5;
\`\`\`

### استعلامات الذاكرة
\`\`\`sql
-- إحصائيات الأحداث
SELECT * FROM v_legacy_event_counts;

-- الذكريات الشخصية
SELECT * FROM v_legacy_identity_memories;

-- الأهداف ذات الأولوية
SELECT * FROM v_legacy_identity_goals 
WHERE priority = 'high';

-- الأنظمة المشتركة
SELECT * FROM v_legacy_shared_systems;
\`\`\`

### استعلامات متقدمة
\`\`\`sql
-- المستندات الأكثر محتوى
SELECT id, source_type, title, LENGTH(content) as content_length
FROM documents 
WHERE content IS NOT NULL
ORDER BY content_length DESC 
LIMIT 10;

-- توزيع الأحداث حسب النوع
SELECT event_type, COUNT(*) as count,
       ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM events), 2) as percentage
FROM events
GROUP BY event_type
ORDER BY count DESC;
\`\`\`

## 🛠️ أدوات الصيانة

### التحقق من صحة النظام
\`\`\`bash
./tools/final_verification.sh
\`\`\`

### نسخ احتياطي سريع
\`\`\`bash
# نسخ قواعد البيانات
cp /opt/hyper-factory/var/db/knowledge/knowledge_main.db /root/backups/
cp /opt/hyper-factory/var/db/memory/memory_core_2025.db /root/backups/
cp /opt/hyper-factory/var/db/identity/identity.db /root/backups/
\`\`\`

### مراقبة الأداء
\`\`\`bash
# مراقبة حجم القواعد البيانات
watch -n 60 'du -h /opt/hyper-factory/var/db/knowledge/knowledge_main.db'

# تعداد المستندات الجديدة
sqlite3 /opt/hyper-factory/var/db/knowledge/knowledge_main.db \\
  "SELECT COUNT(*) FROM documents WHERE created_at > datetime('now', '-1 day');"
\`\`\`

## 🎯 حالات استخدام شائعة

### 1. البحث عن معلومات تقنية
\`\`\`sql
SELECT title, substr(content, 1, 200) AS preview
FROM documents 
WHERE (content LIKE '%docker%' OR content LIKE '%kubernetes%')
  AND source_type = 'knowledge_base'
LIMIT 5;
\`\`\`

### 2. تحليل نشاط النظام
\`\`\`sql
SELECT event_type, COUNT(*) as event_count,
       MIN(timestamp) as first_seen,
       MAX(timestamp) as last_seen
FROM events
GROUP BY event_type
ORDER BY event_count DESC;
\`\`\`

### 3. مراجعة الأهداف
\`\`\`sql
SELECT goal_type, description, priority, status
FROM v_legacy_identity_goals
ORDER BY 
  CASE priority 
    WHEN 'high' THEN 1
    WHEN 'medium' THEN 2 
    WHEN 'low' THEN 3
    ELSE 4
  END,
  created_at DESC;
\`\`\`

## ⚠️ نصائح مهمة

1. **النسخ الاحتياطي**: احفظ نسخة من قواعد البيانات قبل إجراء تغييرات كبيرة
2. **الفهارس**: استخدم الفهارس المضمنة (\`content_hash\`, \`source_type\`, etc.)
3. **الأداء**: تجنب \`SELECT *\` في الجداول الكبيرة، استخدم \`LIMIT\`
4. **المحتوى**: استخدم \`substr(content, 1, N)\` لعرض أجزاء من المحتوى الطويل

## 🔄 تحديث التقارير
\`\`\`bash
# تحديث تقرير الهجرة
sqlite3 /opt/hyper-factory/var/db/knowledge/knowledge_main.db ".read sql/legacy_migration_report.sql"

# تحديث التحليلات
sqlite3 /opt/hyper-factory/var/db/knowledge/knowledge_main.db ".read sql/advanced_analytics_views.sql"
\`\`\`
