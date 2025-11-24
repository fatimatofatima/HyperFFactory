#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="/root/HyperFFactory"
PLAN="$ROOT/plans/HF_EXEC_PLAN.tsv"

if [ ! -f "$PLAN" ]; then
  echo "❌ لم يتم العثور على الملف: $PLAN"
  exit 1
fi

echo "== HyperFFactory – Fix HF_EXEC_PLAN.tsv =="
echo "PLAN : $PLAN"
header="$(head -n1 "$PLAN")"
echo "Current header: $header"

# إذا كان CODE موجودًا بالفعل لا نلمس الملف
if printf '%s\n' "$header" | grep -q "CODE"; then
  echo "✅ الأعمدة CODE / TITLE موجودة بالفعل – لا تعديل."
  exit 0
fi

backup="${PLAN}.bak_$(date +%Y%m%d_%H%M%S)"
cp "$PLAN" "$backup"
echo "📦 تم إنشاء نسخة احتياطية: $backup"

tmp="${PLAN}.tmp"

# إعادة كتابة الملف مع إضافة CODE و TITLE
awk -F'\t' 'NR==1 {
  # رأس جديد
  print "ID\tSTAGE\tCATEGORY\tCODE\tTITLE\tTASK\tSTATUS\tOWNER\tLAST_NOTE";
  next
}
{
  id    = $1;
  stage = $2;
  cat   = $3;
  task  = $4;
  stat  = $5;
  owner = $6;
  note  = $7;

  code  = id;     # يمكن لاحقاً تخصيصه أكثر إذا احتجت
  title = task;   # العنوان = نص الـ TASK الحالي

  print id "\t" stage "\t" cat "\t" code "\t" title "\t" task "\t" stat "\t" owner "\t" note;
}' "$backup" > "$tmp"

mv "$tmp" "$PLAN"

echo "✅ تم تحديث HF_EXEC_PLAN.tsv وإضافة الأعمدة CODE و TITLE."
echo "   النسخة الأصلية محفوظة في: $backup"
