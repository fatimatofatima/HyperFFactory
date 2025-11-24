#!/bin/bash

UNPACK_DIR="$1"
COLLECTION_DIR="$2"
LOG_FILE="$3"

echo "=== بدء جمع قواعد البيانات الفريدة ===" | tee -a "$LOG_FILE"

# مجلد للقواعد الفريدة
UNIQUE_DIR="$COLLECTION_DIR/unique_databases"
mkdir -p "$UNIQUE_DIR"

# مجلد للقواعد المكررة
DUPLICATES_DIR="$COLLECTION_DIR/duplicate_databases" 
mkdir -p "$DUPLICATES_DIR"

# سجل الـ Hashes
HASH_FILE="$COLLECTION_DIR/database_hashes.txt"
echo "hash,file_path,size" > "$HASH_FILE"

UNIQUE_COUNT=0
DUPLICATE_COUNT=0
TOTAL_SIZE=0

process_database() {
    local db_file="$1"
    local file_name=$(basename "$db_file")
    
    # حساب الـ hash للمحتوى
    local file_hash=$(sha256sum "$db_file" | cut -d' ' -f1)
    local file_size=$(stat -c%s "$db_file")
    
    echo "$file_hash,$db_file,$file_size" >> "$HASH_FILE"
    
    # التحقق إذا كان الـ hash موجود مسبقاً
    if grep -q "^$file_hash," "$HASH_FILE" && [ $(grep -c "^$file_hash," "$HASH_FILE") -gt 1 ]; then
        # ملف مكرر
        local duplicate_name="duplicate_${DUPLICATE_COUNT}_$file_name"
        cp "$db_file" "$DUPLICATES_DIR/$duplicate_name"
        echo "🔁 مكرر: $db_file → $duplicate_name" | tee -a "$LOG_FILE"
        DUPLICATE_COUNT=$((DUPLICATE_COUNT + 1))
    else
        # ملف فريد
        local unique_name="db_${UNIQUE_COUNT}_$file_name"
        cp "$db_file" "$UNIQUE_DIR/$unique_name"
        echo "✅ فريد: $db_file → $unique_name" | tee -a "$LOG_FILE"
        UNIQUE_COUNT=$((UNIQUE_COUNT + 1))
        TOTAL_SIZE=$((TOTAL_SIZE + file_size))
    fi
}

# معالجة جميع قواعد البيانات
while IFS= read -r db_file; do
    if [ -f "$db_file" ] && [ -s "$db_file" ]; then
        process_database "$db_file"
    else
        echo "⚠️  ملف فارغ أو غير موجود: $db_file" | tee -a "$LOG_FILE"
    fi
done < "$COLLECTION_DIR/all_dbs_found.txt"

echo "=== نتائج الجمع ===" | tee -a "$LOG_FILE"
echo "📊 إجمالي قواعد البيانات: $((UNIQUE_COUNT + DUPLICATE_COUNT))" | tee -a "$LOG_FILE"
echo "✅ قواعد فريدة: $UNIQUE_COUNT" | tee -a "$LOG_FILE"
echo "🔁 قواعد مكررة: $DUPLICATE_COUNT" | tee -a "$LOG_FILE"
echo "💾 الحجم الإجمالي للبيانات الفريدة: $((TOTAL_SIZE / 1024 / 1024)) MB" | tee -a "$LOG_FILE"
echo "📁 المجلد الفريد: $UNIQUE_DIR" | tee -a "$LOG_FILE"
echo "📁 مجلد المكررات: $DUPLICATES_DIR" | tee -a "$LOG_FILE"
