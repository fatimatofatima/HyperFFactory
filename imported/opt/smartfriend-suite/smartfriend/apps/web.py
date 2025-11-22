"""
SmartFriend Suite - Web UI (placeholder)

تطبيق ويب بسيط يعمل على البورت 8390 عن طريق sf-web.service.
يمكن لاحقًا استبداله بواجهة متقدمة مرتبطة بـ FFactory/Unified.
"""

from fastapi import FastAPI
from fastapi.responses import HTMLResponse, RedirectResponse

app = FastAPI(
    title="SmartFriend Web UI (placeholder)",
    version="0.1.0",
)

@app.get("/health", tags=["health"])
async def health():
    return {"status": "ok", "component": "web-ui", "mode": "placeholder"}

@app.get("/", response_class=HTMLResponse, tags=["ui"])
async def index():
    # يمكن تعديل الرابط لاحقًا ليتكامل مع لوحة ffactory
    html = """
    <!DOCTYPE html>
    <html lang="ar">
    <head>
        <meta charset="utf-8" />
        <title>SmartFriend Web UI</title>
        <style>
            body { font-family: sans-serif; direction: rtl; text-align: right; margin: 40px; }
            .box { max-width: 600px; margin: auto; border: 1px solid #ccc; padding: 20px; border-radius: 8px; }
            a { text-decoration: none; }
        </style>
    </head>
    <body>
        <div class="box">
            <h1>SmartFriend Web UI (Placeholder)</h1>
            <p>واجهة ويب مبدئية للسيوت. تم تشغيلها فقط لضمان صحة المسار والخدمة.</p>
            <p>لوحة FFactory الحالية متاحة عبر <code>/ffactory/docs</code> من خلال Nginx.</p>
            <p><a href="/ffactory/docs">الانتقال إلى لوحة FFactory (عبر Nginx)</a></p>
        </div>
    </body>
    </html>
    """
    return html

@app.get("/redirect/ffactory")
async def redirect_ffactory():
    return RedirectResponse(url="/ffactory/docs")
