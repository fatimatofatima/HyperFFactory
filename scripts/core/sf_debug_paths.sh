#!/usr/bin/env bash
set -Eeuo pipefail

echo "🔍 فحص المسارات والاستيراد..."

cd /opt/smartfriend-suite

echo "📁 المسار الحالي: $(pwd)"
echo "📦 ملف sf_knowledge_client_complete.py موجود: $(ls -la sf_knowledge_client_complete.py 2>/dev/null || echo '❌ غير موجود')"

echo ""
echo "🧪 اختبار الاستيراد من المسار الحالي:"
python3 -c "
import sys
import os

print('📋 sys.path قبل التعديل:')
for p in sys.path:
    print(f'   {p}')

print('')
# إضافة المسار الحالي
current_dir = '/opt/smartfriend-suite'
if current_dir not in sys.path:
    sys.path.insert(0, current_dir)

print('📋 sys.path بعد التعديل:')
for p in sys.path[:3]:  # أول 3 مسارات فقط
    print(f'   {p}')

print('')
try:
    from sf_knowledge_client_complete import KnowledgeClient
    print('✅ استيراد KnowledgeClient ناجح!')
    
    # اختبار إنشاء كائن
    client = KnowledgeClient()
    print('✅ إنشاء كائن KnowledgeClient ناجح!')
    
    # اختبار الدوال
    import asyncio
    async def test():
        try:
            results = await client.search('python', limit=2)
            print(f'✅ البحث ناجح: {len(results)} نتيجة')
        except Exception as e:
            print(f'❌ فشل البحث: {e}')
    
    asyncio.run(test())
    
except ImportError as e:
    print(f'❌ فشل الاستيراد: {e}')
    print('🔧 محاولة الاستيراد المباشر...')
    try:
        import importlib.util
        spec = importlib.util.spec_from_file_location('knowledge_client', '/opt/smartfriend-suite/sf_knowledge_client_complete.py')
        knowledge_module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(knowledge_module)
        print('✅ الاستيراد المباشر ناجح!')
    except Exception as e2:
        print(f'❌ فشل الاستيراد المباشر: {e2}')
except Exception as e:
    print(f'❌ خطأ آخر: {e}')
"
