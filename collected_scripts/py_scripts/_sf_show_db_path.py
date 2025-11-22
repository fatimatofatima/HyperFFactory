import sys
try:
    from smartfrind.db import DB
except Exception as e:
    print(f"ERROR:{e}", file=sys.stderr)
    sys.exit(1)
# اطبع المسار فقط
print(DB)
