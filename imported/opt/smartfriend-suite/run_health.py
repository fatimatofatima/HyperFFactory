#!/usr/bin/env python3
import sys
import os

# إضافة المسار إلى sys.path
sys.path.insert(0, '/opt/smartfriend-suite')

try:
    from apps.health.app import app
    import uvicorn
    
    if __name__ == "__main__":
        print("🚀 بدء تشغيل Health API على المنفذ 8215...")
        uvicorn.run(app, host="0.0.0.0", port=8215, log_level="info")
except Exception as e:
    print(f"❌ فشل في تشغيل Health API: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
