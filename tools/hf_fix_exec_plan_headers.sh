#!/usr/bin/env bash
# HyperFFactory – Fix HF_EXEC_PLAN.tsv headers (add CODE, TITLE)

set -euo pipefail

ROOT="/root/HyperFFactory"
PLAN_DIR="$ROOT/plans"
PLAN_FILE="$PLAN_DIR/HF_EXEC_PLAN.tsv"

cd "$ROOT"

if [ ! -f "$PLAN_FILE" ]; then
  echo "❌ HF_EXEC_PLAN.tsv غير موجود في $PLAN_DIR"
  exit 1
fi

TS="$(date +%Y%m%d_%H%M%S)"
BACKUP="${PLAN_FILE%.tsv}_backup_${TS}.tsv"

cp "$PLAN_FILE" "$BACKUP"
echo "📦 Backup created: $BACKUP"

TMP="${PLAN_FILE}.tmp"

awk -F'\t' -v OFS='\t' '
NR==1 {
  has_code=0; has_title=0;
  for (i=1;i<=NF;i++) {
    if ($i=="CODE")  has_code=1;
    if ($i=="TITLE") has_title=1;
  }
  if (has_code && has_title) {
    print $0;
    next;
  }
  hdr="CODE\tTITLE\t";
  for (i=1;i<=NF;i++) {
    hdr=hdr $i;
    if (i<NF) hdr=hdr "\t";
  }
  print hdr;
  next;
}
NR>1 {
  # نفترض ترتيب الحقول القديم:
  # $1 = ID,  $4 = TASK
  code=$1;
  title=$4;
  print code, title, $0;
}
' "$BACKUP" > "$TMP"

mv "$TMP" "$PLAN_FILE"
echo "✅ HF_EXEC_PLAN.tsv تم تحديثه مع CODE و TITLE."
echo "   الملف الأصلي محفوظ في: $BACKUP"
