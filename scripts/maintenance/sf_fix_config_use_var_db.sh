#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_FILE="/opt/smartfriend-suite/smartfriend/app/smartfrind/config.py"
BACKUP_FILE="${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
OLD="/opt/smartfriend-suite/data/smartfriend_unified.db"
NEW="/opt/smartfriend-suite/var/db/smartfriend_unified.db"

echo "[*] نسخ احتياطي لملف config.py إلى: $BACKUP_FILE"
cp "$CONFIG_FILE" "$BACKUP_FILE"

echo "[*] تعديل مسار DB داخل config.py ليشير إلى var/db ..."
sed -i "s|$OLD|$NEW|g" "$CONFIG_FILE"

echo "[OK] تم ضبط config.py على: $NEW"
