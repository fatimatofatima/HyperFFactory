#!/usr/bin/env bash
# HyperFFactory – Prepare Official Backup Dirs (No actual backup)

set -euo pipefail

ROOT="/root/HyperFFactory"
cd "$ROOT"

BACK_DIR="$ROOT/data/backups/hf"

mkdir -p "$BACK_DIR"

README="$BACK_DIR/README_hf_backups.txt"

if [ ! -f "$README" ]; then
  cat > "$README" <<'RMD'
HyperFFactory – Official HF Backups Directory
=============================================

هذا المجلد مخصّص لنسخ HyperFFactory الرسمية بصيغة tar.zst
(مثل: hyper-factory_full_YYYYMMDD_HHMMSS.tar.zst).

حتى الآن لا توجد نسخ فعلية هنا.
النسخ القديمة موجودة تحت: backups_legacy/

السياسة المقترحة:
- يوميًّا: db/, db/meta/, config/
- أسبوعيًّا: sql/, reports/
- شهريًّا: backups_legacy/, data/

هذه الملاحظة للتوثيق فقط؛ لا يوجد أي سكربت هنا يقوم بالنسخ تلقائيًا.
RMD
fi

echo "ROOT      : $ROOT"
echo "BACK_DIR  : $BACK_DIR"
echo "STATUS    : جاهز للاستخدام (مسار موجود، بدون نسخ فعلية)."
