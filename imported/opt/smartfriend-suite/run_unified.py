#!/usr/bin/env python3
import sys
import os

# إضافة المسار إلى sys.path
sys.path.insert(0, '/opt/smartfriend-suite')

try:
    from apps.unified.app import app
    import uvicorn
    
    if __name__ == "__main__":
        print("🚀 بدء تشغيل Unified API على المنفذ 8220...")
        uvicorn.run(app, host="0.0.0.0", port=8220, log_level="info")
except Exception as e:
    print(f"❌ فشل في تشغيل Unified API: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
