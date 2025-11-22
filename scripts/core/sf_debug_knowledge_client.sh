#!/usr/bin/env bash
set -Eeuo pipefail

echo "🔍 فحص مشكلة استيراد KnowledgeClient..."

cd /opt/smartfriend-suite

echo "📁 المسار الحالي: $(pwd)"
echo "📦 ملفات Python في المسار الحالي:"
ls -la *.py 2>/dev/null | head -10

echo ""
echo "🧪 اختبار استيراد KnowledgeClient مباشرة:"
python3 -c "
import sys
print('📋 مسارات Python:')
for path in sys.path:
    print(f'   {path}')

print('')
try:
    from sf_knowledge_client_complete import KnowledgeClient
    print('✅ استيراد KnowledgeClient ناجح من المسار الحالي')
    
    # اختبار إنشاء كائن
    client = KnowledgeClient()
    print('✅ إنشاء كائن KnowledgeClient ناجح')
    
except ImportError as e:
    print(f'❌ فشل الاستيراد: {e}')
    print('🔧 محاولة استيراد من المسار المطلق...')
    try:
        import importlib.util
        spec = importlib.util.spec_from_file_location('knowledge_client', '/opt/smartfriend-suite/sf_knowledge_client_complete.py')
        knowledge_module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(knowledge_module)
        print('✅ استيراد من المسار المطلق ناجح')
    except Exception as e2:
        print(f'❌ فشل الاستيراد المطلق: {e2}')
except Exception as e:
    print(f'❌ خطأ آخر: {e}')
"

echo ""
echo "📄 محتوى ملف KnowledgeClient (الأول 10 أسطر):"
head -10 /opt/smartfriend-suite/sf_knowledge_client_complete.py

echo ""
echo "🔧 إضافة المسار الحالي إلى sys.path في البوابة..."
