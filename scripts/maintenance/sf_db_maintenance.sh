#!/bin/bash
DB="/opt/smartfriend-suite/data/smartfriend_unified.db"
echo "$(date): Starting DB maintenance"
sqlite3 "$DB" "PRAGMA wal_checkpoint(TRUNCATE);" 2>/dev/null
sqlite3 "$DB" "PRAGMA integrity_check;" | grep -q "ok" && echo "Integrity: OK" || echo "Integrity: FAILED"
echo "$(date): DB maintenance completed"
