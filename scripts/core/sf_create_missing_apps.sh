#!/bin/bash
echo "🛠️ إنشاء التطبيقات المفقودة لـ SmartFriend Suite"

# التأكد من وجود مجلد apps
mkdir -p /opt/smartfriend-suite/apps

# 1. إنشاء تطبيق unified الأساسي
echo "📦 إنشاء تطبيق unified..."
mkdir -p /opt/smartfriend-suite/apps/unified

cat > /opt/smartfriend-suite/apps/unified/__init__.py <<'UNIFIED_INIT'
from fastapi import FastAPI

app = FastAPI(
    title="SmartFriend Unified API",
    description="البوابة الموحدة لخدمات SmartFriend",
    version="1.0.0"
)

@app.get("/")
async def root():
    return {"message": "SmartFriend Unified API - البوابة الموحدة"}

@app.get("/health")
async def health():
    return {"status": "healthy", "service": "unified"}

@app.get("/ask")
async def ask(question: str = "Hello"):
    return {
        "question": question,
        "answer": f"تم استلام سؤالك: {question}",
        "service": "unified"
    }
UNIFIED_INIT

# 2. إنشاء تطبيق memory الأساسي
echo "🧠 إنشاء تطبيق memory..."
mkdir -p /opt/smartfriend-suite/apps/memory

cat > /opt/smartfriend-suite/apps/memory/__init__.py <<'MEMORY_INIT'
from fastapi import FastAPI

app = FastAPI(
    title="SmartFriend Memory API",
    description="واجهة الذاكرة لخدمات SmartFriend",
    version="1.0.0"
)

@app.get("/")
async def root():
    return {"message": "SmartFriend Memory API - نظام الذاكرة"}

@app.get("/health")
async def health():
    return {"status": "healthy", "service": "memory"}

@app.get("/recall")
async def recall(key: str = "default"):
    return {
        "key": key,
        "value": f"بيانات الذاكرة للمفتاح: {key}",
        "service": "memory"
    }
MEMORY_INIT

# 3. إنشاء تطبيق web الأساسي
echo "🌐 إنشاء تطبيق web..."
mkdir -p /opt/smartfriend-suite/apps/web

cat > /opt/smartfriend-suite/apps/web/__init__.py <<'WEB_INIT'
from fastapi import FastAPI
from fastapi.responses import HTMLResponse

app = FastAPI(
    title="SmartFriend Web Dashboard",
    description="لوحة التحكم لخدمات SmartFriend",
    version="1.0.0"
)

@app.get("/", response_class=HTMLResponse)
async def root():
    return """
    <!DOCTYPE html>
    <html>
    <head>
        <title>SmartFriend Suite - لوحة التحكم</title>
        <meta charset="utf-8">
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
            .container { max-width: 800px; margin: 0 auto; background: white; padding: 20px; border-radius: 10px; }
            h1 { color: #333; }
            .service { padding: 10px; margin: 10px 0; background: #e8f4fd; border-radius: 5px; }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🚀 SmartFriend Suite - لوحة التحكم</h1>
            <p>مرحباً بك في النظام الموحد لـ SmartFriend</p>
            
            <div class="service">
                <h3>🔗 الخدمات المتاحة:</h3>
                <ul>
                    <li><a href="/unified/">Unified API</a> - البوابة الموحدة</li>
                    <li><a href="/memory/">Memory API</a> - نظام الذاكرة</li>
                    <li><a href="/core/">Core API</a> - النواة الأساسية</li>
                    <li><a href="/ffactory/">FFactory</a> - المصنع الذكي</li>
                </ul>
            </div>
        </div>
    </body>
    </html>
    """

@app.get("/health")
async def health():
    return {"status": "healthy", "service": "web"}
WEB_INIT

# 4. إنشاء تطبيق health الأساسي
echo "❤️ إنشاء تطبيق health..."
mkdir -p /opt/smartfriend-suite/apps/health

cat > /opt/smartfriend-suite/apps/health/__init__.py <<'HEALTH_INIT'
from fastapi import FastAPI

app = FastAPI(
    title="SmartFriend Health API",
    description="نظام المراقبة الصحية لخدمات SmartFriend",
    version="1.0.0"
)

@app.get("/")
async def root():
    return {"message": "SmartFriend Health API - نظام المراقبة"}

@app.get("/health")
async def health():
    return {"status": "healthy", "service": "health"}

@app.get("/status")
async def status():
    return {
        "status": "operational",
        "services": {
            "core": "healthy",
            "unified": "healthy", 
            "memory": "healthy",
            "web": "healthy"
        }
    }
HEALTH_INIT

# 5. إنشاء ملف __init__.py للمجلد الرئيسي
cat > /opt/smartfriend-suite/apps/__init__.py <<'APPS_INIT'
"""
SmartFriend Suite - حزمة التطبيقات الرئيسية
"""

__version__ = "1.0.0"
__author__ = "SmartFriend Team"

# جعل المجلد package صالح للاستيراد
APPS_INIT

echo "✅ تم إنشاء جميع التطبيقات الأساسية بنجاح!"
echo "📁 الملفات المنشأة:"
find /opt/smartfriend-suite/apps -name "*.py" | head -10

echo ""
echo "🔧 الخطوة التالية: إعادة تشغيل الخدمات الفاشلة"
