#!/usr/bin/env python3
import sys
import os

# إضافة المسار إلى sys.path
sys.path.insert(0, '/opt/smartfriend-suite')

try:
    from apps.web.app import app
    import uvicorn
    
    if __name__ == "__main__":
        print("🚀 بدء تشغيل Web UI على المنفذ 8390...")
        uvicorn.run(app, host="0.0.0.0", port=8390, log_level="info")
except Exception as e:
    print(f"❌ فشل في تشغيل Web UI: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
