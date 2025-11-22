#!/usr/bin/env bash
set -euo pipefail
echo "== OS, Disk, Memory =="
uname -a; df -h /; free -h || true
echo; echo "== Tesseract =="
tesseract --version || true
echo; echo "== Python venv =="
/opt/osmart/venv/bin/python -V || true
/opt/osmart/venv/bin/python - <<'PY' || true
import cv2,psycopg2,pytesseract
print("cv2", getattr(cv2,'__version__','?'))
print("pytesseract", getattr(pytesseract, 'get_tesseract_version', lambda:'?')())
print("psycopg2 OK")
PY
echo; echo "== Postgres & perms =="
sudo -u postgres psql -d osmart -c "SELECT current_user, current_database();" || true
sudo -u postgres psql -d osmart -c "SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY 1 LIMIT 30;" || true
echo; echo "== Indexes health =="
sudo -u postgres psql -d osmart -c "SELECT relname, n_dead_tup FROM pg_stat_user_tables ORDER BY n_dead_tup DESC LIMIT 10;" || true
echo; echo "== Worker status =="
osmart-job status || true
echo "[OK] selfcheck done"
