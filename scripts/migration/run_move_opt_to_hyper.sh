#!/usr/bin/env bash
set -euo pipefail

cd /root/HyperFFactory

echo "تشغيل نقل /opt إلى imported/opt داخل HyperFFactory (باستثناء ffactory*)"
echo

python3 scripts/migration/hyper_move_opt_to_hyper.py
