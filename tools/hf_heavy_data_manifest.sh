#!/usr/bin/env bash
# HyperFFactory – Heavy Data Manifest (P2-6)
# ينتج ملف TSV يعرّف "ملفات/مجلدات الداتا الثقيلة / snapshots / imported".
# لا يحذف ولا ينقل أي شيء؛ فقط قياس أحجام وكتابة manifest.

set -euo pipefail

ROOT="/root/HyperFFactory"
cd "$ROOT"

META_DIR="db/meta"
REPORT_DIR="reports"
mkdir -p "$META_DIR" "$REPORT_DIR"

TS="$(date +%Y%m%d_%H%M%S)"
MANIFEST="${META_DIR}/hf_heavy_data_manifest.tsv"
LOG="${REPORT_DIR}/hf_heavy_data_manifest_${TS}.log"

# جذور نفحصها (تقدر تعدّلها لاحقًا لو حبيت)
SCAN_ROOTS=(
  "data"
  "backups_legacy"
  "reports"
  "db"
)

# نكتب Header للمانيفست (نستبدل أي ملف قديم)
{
  echo -e "PATH\tSIZE_H\tSIZE_MB\tCATEGORY\tNOTE"
} > "$MANIFEST"

{
  echo "====================================================="
  echo "[HEAVY-DATA] HyperFFactory – Heavy Data Manifest"
  echo "ROOT : ${ROOT}"
  echo "TIME : ${TS}"
  echo "MAN  : ${MANIFEST}"
  echo "LOG  : ${LOG}"
  echo "====================================================="
  echo

  echo "1) Scanning directories (maxdepth=2) and computing size in MB..."
  echo "-----------------------------------------------------"

  TMP="$(mktemp)"
  trap 'rm -f "$TMP"' EXIT

  for root in "${SCAN_ROOTS[@]}"; do
    if [[ -d "$root" ]]; then
      echo "[SCAN] $root"
      # du -sm حتى عمق 2، ثم sort تنازلي
      find "$root" -maxdepth 2 -mindepth 1 -type d 2>/dev/null | \
        xargs -r du -sm 2>/dev/null >> "$TMP"
    else
      echo "[MISS] $root (directory not found)"
    fi
  done

  if [[ ! -s "$TMP" ]]; then
    echo "[WARN] لا توجد مجلدات مرشحة أو لا يوجد أي حجم مقاس."
  else
    sort -nr "$TMP" -o "$TMP"

    echo
    echo "2) Writing manifest (PATH, SIZE_H, SIZE_MB, CATEGORY, NOTE)"
    echo "-----------------------------------------------------"

    # نكتب أيضًا Top 20 في اللوج
    top_count=0

    while read -r size_mb path; do
      [[ -z "$path" ]] && continue

      size_h="${size_mb}M"

      # تصنيف بسيط حسب الحجم
      category="normal"
      if (( size_mb >= 5000 )); then
        category="critical-heavy"
      elif (( size_mb >= 1000 )); then
        category="heavy"
      elif (( size_mb >= 100 )); then
        category="medium"
      fi

      note="AUTO_SCANNED"

      # إضافة للسطر في manifest
      echo -e "${path}\t${size_h}\t${size_mb}\t${category}\t${note}" >> "$MANIFEST"

      # Snapshot لأكبر 20 عنصر في اللوج
      if (( top_count < 20 )); then
        printf "  %6s MB  | %-60s | %s\n" "$size_mb" "$path" "$category"
        top_count=$((top_count + 1))
      fi
    done < "$TMP"

    echo
    echo "-----------------------------------------------------"
    echo "[INFO] Manifest written to: ${MANIFEST}"
    echo "[INFO] Top ${top_count} heavy entries shown above."
  fi

  echo
  echo "-----------------------------------------------------"
  echo "[NOTE] هذا السكربت لا يحذف ولا ينقل أي شيء."
  echo "      الهدف فقط: تعريف واضح لـ 'الداتا الثقيلة / snapshots / imported' في ملف واحد."
  echo "-----------------------------------------------------"
} | tee "$LOG"

echo
echo "[HEAVY-DATA] Manifest + report ready."
