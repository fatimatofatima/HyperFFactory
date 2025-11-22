#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

FILE="/opt/smartfriend-suite/smartfriend/app/smartfrind/ingest_agent.py"

echo "[*] ضبط صلاحيات $FILE ..."
if [ ! -f "$FILE" ]; then
  echo "[ERROR] الملف غير موجود: $FILE" >&2
  exit 1
fi

chown smartfriend-suite:smartfriend-suite "$FILE" 2>/dev/null || true
chmod 640 "$FILE"

echo "[OK] ls -la:"
ls -la "$FILE"

echo "[*] إعادة تشغيل خدمة ingest ..."
systemctl restart smartfrind-ingest.service || true
sleep 1
systemctl status smartfrind-ingest.service --no-pager -l || true
