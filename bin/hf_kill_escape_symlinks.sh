#!/usr/bin/env bash
# HyperFFactory – Move escape symlinks out of unified tree إلى الأرشيف

set -euo pipefail

ROOT="/root/HyperFFactory"
ARCHIVE_ROOT="/root/HyperFFactory_archives/escape_symlinks"

cd "$ROOT"

LOG_LATEST="$(ls -t reports/hf_assert_unified_tree_*.log 2>/dev/null | head -n1 || true)"
if [[ -z "${LOG_LATEST:-}" ]]; then
  echo "❌ لا يوجد تقرير hf_assert_unified_tree_* في reports/ – شغّل bin/hf_assert_unified_tree.sh أولاً."
  exit 1
fi

TS="$(date '+%Y%m%d_%H%M%S')"
OUT_LOG="reports/hf_kill_escape_symlinks_${TS}.log"

mkdir -p "$(dirname "$OUT_LOG")"
mkdir -p "$ARCHIVE_ROOT"

echo "==================================================" | tee "$OUT_LOG"
echo "🧹 HF – Fix Escape Symlinks" | tee -a "$OUT_LOG"
echo "ROOT        : $ROOT" | tee -a "$OUT_LOG"
echo "ASSERT_LOG  : $LOG_LATEST" | tee -a "$OUT_LOG"
echo "ARCHIVE_DIR : $ARCHIVE_ROOT" | tee -a "$OUT_LOG"
echo "TIME        : $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$OUT_LOG"
echo "==================================================" | tee -a "$OUT_LOG"
echo | tee -a "$OUT_LOG"

# استخراج المسارات من سطور "Escape symlink"
TMP_PATHS="$(mktemp)"
grep 'Escape symlink' "$LOG_LATEST" \
  | sed -E 's/.*: ([^ ]+) →.*/\1/' \
  | sort -u > "$TMP_PATHS"

if [[ ! -s "$TMP_PATHS" ]]; then
  echo "✅ لا يوجد symlinks هاربة في التقرير." | tee -a "$OUT_LOG"
  rm -f "$TMP_PATHS"
  exit 0
fi

while IFS= read -r P; do
  # نتأكد أن المسار تحت ROOT
  case "$P" in
    "$ROOT"/*) ;;
    *)
      echo "⚠️ تخطي مسار خارج ROOT (من التقرير): $P" | tee -a "$OUT_LOG"
      continue
      ;;
  esac

  if [[ ! -L "$P" ]]; then
    echo "ℹ️ symlink غير موجود الآن (ربما نُقل سابقًا): $P" | tee -a "$OUT_LOG"
    continue
  fi

  # نحوله لمسار نسبي داخل الجذر
  REL="${P#"$ROOT"/}"
  DEST="$ARCHIVE_ROOT/$REL"

  echo "--------------------------------------------------" | tee -a "$OUT_LOG"
  echo "↪ معالجة symlink هارب:" | tee -a "$OUT_LOG"
  echo "   SRC : $P" | tee -a "$OUT_LOG"
  echo "   DST : $DEST" | tee -a "$OUT_LOG"

  mkdir -p "$(dirname "$DEST")"

  # mv هنا ينقل الـ symlink نفسه فقط، لا يلمس الهدف /opt/...
  mv "$P" "$DEST"

  echo "   ✅ نُقل symlink إلى الأرشيف." | tee -a "$OUT_LOG"
done < "$TMP_PATHS"

rm -f "$TMP_PATHS"

echo "==================================================" | tee -a "$OUT_LOG"
echo "✅ انتهت معالجة symlinks الهاربة. راجع اللوج: $OUT_LOG" | tee -a "$OUT_LOG"
