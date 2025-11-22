# 🚀 دليل استخدام HyperFFactory - الإصدار النهائي

## 📊 نظرة عامة حقيقية على البيانات
- **المعرفة**: 152,053 مستند (804MB) - ✅ تعمل
- **الذاكرة**: 619 حدث في جدول `events` - ✅ مصححة
- **الهوية**: 61 كيان (أنظمة، أهداف، ذكريات) - ✅ مصححة

## 🎯 الحالة النهائية
- ✅ جميع واجهات المعرفة تعمل بشكل صحيح  
- ✅ واجهات الذاكرة مصححة وتستخدم بيانات `events` الفعلية
- ✅ البيانات الحقيقية معروضة بشكل صحيح

## 🔍 استعلامات سريعة (محدثة نهائياً)

### استعلامات المعرفة
\`\`\`sql
-- أحدث المستندات
SELECT * FROM v_knowledge_documents_recent LIMIT 10;

-- تحليل المصادر
SELECT * FROM v_knowledge_documents_by_source_type;

-- بحث تقني
SELECT id, title, substr(content, 1, 100) AS preview 
FROM documents 
WHERE content LIKE '%python%' OR content LIKE '%docker%'
LIMIT 5;
\`\`\`

### استعلامات الذاكرة (المصححة والفعّالة)
\`\`\`sql
-- إحصائيات الأحداث (الأكثر نشاطاً)
SELECT * FROM v_legacy_event_counts LIMIT 8;

-- نظرة عامة على الهوية
SELECT * FROM v_legacy_identity_profile;

-- الأنظمة النشطة
SELECT * FROM v_legacy_shared_systems;

-- الذكريات الحديثة
SELECT * FROM v_legacy_identity_memories;

-- الأهداف المسجلة
SELECT * FROM v_legacy_identity_goals;
\`\`\`

## 📈 البيانات الفعلية المتاحة

### الأنظمة والهوية (من الأحداث)
- **meta.db_file**: 539 حدث (نشاط الملفات)
- **legacy.identity.goals**: 20 هدف
- **legacy.shared.systems**: 15 نظام  
- **legacy.identity.identity_profile**: 14 عنصر ملف تعريف
- **legacy.identity.memories**: 12 ذاكرة
- **legacy.active_memory.meta**: 7 أحداث
- **legacy.neural_memory**: 7 أحداث (مهارات وذاكرة)

### الذكريات (أمثلة حقيقية)
- ذاكرة unified_memory - قاعدة موحدة
- ذاكرة smart_core_memory - النواة الذكية  
- ذاكرة active_memory - الذاكرة النشطة
- ذاكرة legacy.memory - الذاكرة الأساسية

## 🛠️ أدوات الصيانة

### التحقق من صحة النظام
\`\`\`bash
./tools/final_verification.sh
\`\`\`

### نسخ احتياطي
\`\`\`bash
# النسخ الاحتياطي اليومي
BACKUP_DIR="/root/backups/$(date +%Y%m%d)"
mkdir -p $BACKUP_DIR
cp /opt/hyper-factory/var/db/knowledge/knowledge_main.db "$BACKUP_DIR/"
cp /opt/hyper-factory/var/db/memory/memory_core_2025.db "$BACKUP_DIR/"
echo "✅ تم النسخ الاحتياطي في: $BACKUP_DIR"
\`\`\`

### مراقبة النمو
\`\`\`bash
# مراقبة حجم المعرفة
sqlite3 /opt/hyper-factory/var/db/knowledge/knowledge_main.db "
SELECT date(created_at) as day, COUNT(*) as new_docs
FROM documents 
WHERE date(created_at) >= date('now', '-7 days')
GROUP BY day
ORDER BY day;"
\`\`\`

## 🎯 أمثلة عملية

### 1. البحث عن معلومات تقنية
\`\`\`sql
SELECT id, title, source_type, substr(content, 1, 150) AS preview
FROM documents 
WHERE content LIKE '%kubernetes%' OR content LIKE '%container%'
ORDER BY created_at DESC
LIMIT 10;
\`\`\`

### 2. تحليل نشاط النظام
\`\`\`sql
SELECT 
  event_type,
  COUNT(*) as event_count,
  MIN(timestamp) as first_seen,
  MAX(timestamp) as last_seen
FROM v_legacy_event_counts
WHERE count > 5
ORDER BY event_count DESC;
\`\`\`

### 3. استكشاف الذكريات
\`\`\`sql
SELECT 
  memory_type,
  COUNT(*) as memory_count,
  MAX(created_at) as last_updated
FROM v_legacy_identity_memories
GROUP BY memory_type
ORDER BY last_updated DESC;
\`\`\`

## 🔧 استكشاف الأخطاء وإصلاحها

### إذا ظهرت أخطاء في الواجهات:
\`\`\`bash
# إعادة تطبيق الإصلاح
sqlite3 /opt/hyper-factory/var/db/memory/memory_core_2025.db ".read sql/memory_views_final_fix.sql"

# التحقق من الجداول
sqlite3 /opt/hyper-factory/var/db/memory/memory_core_2025.db ".tables"
\`\`\`

### لفحص البيانات الخام:
\`\`\`sql
-- رؤية جميع أنواع الأحداث
SELECT DISTINCT event_type FROM events ORDER BY event_type;

-- عينات من payload
SELECT event_type, substr(payload_json, 1, 100) as preview 
FROM events 
WHERE event_type LIKE '%identity%'
LIMIT 5;
\`\`\`

## 📞 الدعم

### ملفات الإصلاح المتاحة:
- `sql/memory_views_final_fix.sql` - إصلاح الواجهات
- `sql/knowledge_core_views_fixed.sql` - واجهات المعرفة
- `tools/final_verification.sh` - فحص النظام

### السجلات:
- `logs/db_health/` - صحة قواعد البيانات
- `reports/` - التقارير والتقارير

## 🎉 الخلاصة

النظام الآن يعمل بشكل كامل مع:
- ✅ 152,053 مستند معرفة قابلة للبحث
- ✅ 619 حدث ذاكرة منظم في واجهات
- ✅ 61 كيان هوية (أهداف، أنظمة، ذكريات)
- ✅ أدوات صيانة واستعلام فعالة

ابدأ باستخدام الاستعلامات أعلاه لاستكشاف نظام HyperFFactory!
