#!/usr/bin/env bash
set -euo pipefail

ROOT="/root/HyperFFactory"
META_DB="$ROOT/meta/hyper_meta.db"
BACKUP_ROOT="$ROOT/backups_db_safe"

TS="$(date +%Y%m%d_%H%M%S)"
DEST="$BACKUP_ROOT/full_${TS}"
LOG="$DEST/backup.log"
MANIFEST="$DEST/manifest.sha256"

mkdir -p "$DEST"

echo "==================================================" | tee -a "$LOG"
echo " HyperFFactory DB SAFE BACKUP (من hyper_meta.db فقط)" | tee -a "$LOG"
echo " Timestamp : $TS" | tee -a "$LOG"
echo " META_DB   : $META_DB" | tee -a "$LOG"
echo " DEST      : $DEST" | tee -a "$LOG"
echo "==================================================" | tee -a "$LOG"

if [[ ! -f "$META_DB" ]]; then
  echo "❌ META DB غير موجود: $META_DB" | tee -a "$LOG"
  exit 1
fi

# استخراج أسماء الأعمدة من db_files
echo "🔎 فحص سكيما db_files..." | tee -a "$LOG"
COLUMNS_RAW="$(sqlite3 "$META_DB" "PRAGMA table_info(db_files);")" || {
  echo "❌ فشل قراءة سكيما db_files من hyper_meta.db" | tee -a "$LOG"
  exit 1
}

# عرض الأعمدة في اللوج
echo "📋 الأعمدة المتاحة في db_files:" | tee -a "$LOG"
echo "$COLUMNS_RAW" | awk -F'|' '{print "  - " $2 " (" $3 ")"}' | tee -a "$LOG"

# اختيار عمود يمثل مسار ملف (أي عمود يحتوي قيم تبدأ بـ /root/)
PATH_COL=""
while IFS='|' read -r cid name type notnull dflt pk; do
  # نبحث عن عمود TEXT فقط
  if [[ "$type" != "TEXT" && "$type" != "" ]]; then
    continue
  fi
  # فحص إذا كان يحتوي مسارات تبدأ بـ /root/
  CNT="$(sqlite3 "$META_DB" "SELECT COUNT(*) FROM db_files WHERE \"$name\" LIKE '/root/%';" 2>/dev/null || echo 0)"
  if [[ "$CNT" != "0" ]]; then
    PATH_COL="$name"
    break
  fi
done <<< "$COLUMNS_RAW"

if [[ -z "$PATH_COL" ]]; then
  echo "❌ لم يتم العثور على عمود يحتوي مسارات تبدأ بـ /root/ في db_files." | tee -a "$LOG"
  echo "   راجع الأعمدة أعلاه لضبط السكربت يدويًا." | tee -a "$LOG"
  exit 1
fi

echo "✅ سيتم استخدام العمود '$PATH_COL' كمسار الملفات." | tee -a "$LOG"

# الأدوار التي سننسخها احتياطيًا (هوية، ذاكرة، معرفة، SmartFriend قديم، data_home)
ROLES="'identity','memory_core','knowledge_hub','smartfriend_legacy','data_home'"

echo "🔎 استخراج قائمة الملفات من hyper_meta.db حسب الأدوار: $ROLES" | tee -a "$LOG"

# نستخدم mode tabs لسهولة المعالجة
FILE_LIST="$DEST/file_list.tsv"
sqlite3 -cmd ".mode tabs" "$META_DB" \
  "SELECT $PATH_COL, role, size_mb FROM db_files WHERE role IN ($ROLES);" > "$FILE_LIST" || {
  echo "❌ فشل استخراج قائمة الملفات من db_files." | tee -a "$LOG"
  exit 1
}

TOTAL_FILES="$(wc -l < "$FILE_LIST" || echo 0)"
echo "📊 عدد الملفات المرشحة للنسخ: $TOTAL_FILES" | tee -a "$LOG"

if [[ "$TOTAL_FILES" -eq 0 ]]; then
  echo "⚠️ لا توجد ملفات مطابقة للأدوار المحددة في db_files." | tee -a "$LOG"
  exit 0
fi

# نسخ الملفات بشكل آمن
COPIED=0
SKIPPED=0
MISSING=0

while IFS=$'\t' read -r SRC ROLE SIZE_MB; do
  if [[ -z "$SRC" ]]; then
    continue
  fi

  # نتأكد أن المسار يبدأ بـ /root/ لتفادي أي مسارات غريبة
  if [[ "$SRC" != /root/* ]]; then
    echo "⚠️ تخطي مسار غير متوقع (لا يبدأ بـ /root/): $SRC" | tee -a "$LOG"
    ((SKIPPED++)) || true
    continue
  fi

  if [[ ! -f "$SRC" ]]; then
    echo "⚠️ ملف غير موجود (سيتم تسجيله فقط): $SRC" | tee -a "$LOG"
    ((MISSING++)) || true
    continue
  fi

  # بناء المسار النسبي داخل النسخة الاحتياطية (نحتفظ بنفس الهيكل قدر الإمكان)
  REL="${SRC#/root/}"
  DEST_PATH="$DEST/$REL"
  DEST_DIR="$(dirname "$DEST_PATH")"
  mkdir -p "$DEST_DIR"

  cp -a "$SRC" "$DEST_PATH"
  echo "$DEST_PATH" >> "$DEST/backup_files.list"
  ((COPIED++)) || true
done < "$FILE_LIST"

echo "--------------------------------------------------" | tee -a "$LOG"
echo "📦 ملخص النسخ:" | tee -a "$LOG"
echo "  ✔️ تم نسخ:    $COPIED ملف" | tee -a "$LOG"
echo "  ⚠️ متخطى:     $SKIPPED ملف (مسارات غير متوقعة)" | tee -a "$LOG"
echo "  ❌ غير موجود: $MISSING ملف (غير موجود على القرص)" | tee -a "$LOG"
echo "--------------------------------------------------" | tee -a "$LOG"

# إنشاء manifest SHA256 للملفات المنسوخة
if [[ -f "$DEST/backup_files.list" ]]; then
  echo "🔐 إنشاء manifest SHA256..." | tee -a "$LOG"
  : > "$MANIFEST"
  while IFS= read -r P; do
    if [[ -f "$P" ]]; then
      sha256sum "$P" >> "$MANIFEST"
    fi
  done < "$DEST/backup_files.list"
  echo "✅ تم إنشاء manifest: $MANIFEST" | tee -a "$LOG"
else
  echo "⚠️ لا توجد ملفات منسوخة، لن يتم إنشاء manifest." | tee -a "$LOG"
fi

echo "==================================================" | tee -a "$LOG"
echo "انتهى النسخ الآمن من hyper_meta.db دون تعديل أي قواعد بيانات أصلية." | tee -a "$LOG"
echo "المجلد النهائي: $DEST" | tee -a "$LOG"
echo "==================================================" | tee -a "$LOG"
