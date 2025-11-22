#!/usr/bin/env bash
set -euo pipefail
echo "== إصلاح الجداول/الفهارس =="
/usr/local/sbin/osmart_pipeline_addons.sh || true
echo "== VACUUM/ANALYZE =="
sudo -u postgres psql -d osmart -c "VACUUM (ANALYZE, VERBOSE);" || true
echo "[OK] repair done"
