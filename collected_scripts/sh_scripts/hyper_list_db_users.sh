#!/usr/bin/env bash
set -euo pipefail

ROOT="/root/HyperFFactory"

ROOTS=(
  "/opt/hyper-factory/var/db"
  "${ROOT}/all_legacy_dbs"
)

echo "=== HyperFFactory - العمليات التي تستخدم قواعد البيانات ==="
echo

if ! command -v lsof >/dev/null 2>&1; then
  echo "❌ الأمر lsof غير مثبت. يمكن تثبيته بواسطة:"
  echo "   apt-get update && apt-get install -y lsof"
  exit 1
fi

for R in "${ROOTS[@]}"; do
  if [[ ! -d "${R}" ]]; then
    echo "— Root: ${R}"
    echo "   ⚠️ المسار غير موجود."
    echo
    continue
  fi

  echo "— Root: ${R}"
  echo "   🔍 فحص العمليات التي تفتح ملفات قواعد بيانات تحت هذا المسار..."
  echo

  # نستخدم +D بحذر على مستوى هذا المسار فقط
  lsof -nP +D "${R}" 2>/dev/null | \
    awk '
      NR==1 {print "PID\tPPID\tUSER\tTYPE\tFD\tSIZE\tDB_PATH"; next}
      $9 ~ /\.db$|\.sqlite$|\.sqlite3$|\.db3$/ {
        # بعض الحقول ثابتة وبعضها من lsof: PID USER FD TYPE SIZE/OFF NODE NAME
        # ما عندنا PPID في مخرجات lsof مباشرة، فنطبع PID/USER/FD/TYPE/SIZE/NAME
        printf "%s\t%s\t%s\t%s\t%s\t%s\n", $2, $3, $4, $5, $7, $9
      }
    '

  echo
done

echo "✅ انتهى الفحص."
