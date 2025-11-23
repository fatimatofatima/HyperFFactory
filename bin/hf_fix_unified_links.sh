#!/usr/bin/env bash
# HyperFFactory - Fix symlinks/hardlinks inside unified tree

set -euo pipefail

ROOT="/root/HyperFFactory"

if [[ ! -d "$ROOT" ]]; then
  echo "❌ الجذر $ROOT غير موجود."
  exit 1
fi

LOG_LATEST="$(ls -t "$ROOT"/reports/hf_assert_unified_tree_*.log 2>/dev/null | head -n1 || true)"
if [[ -z "${LOG_LATEST:-}" ]]; then
  echo "❌ لا يوجد تقرير hf_assert_unified_tree_* في reports/ – شغّل bin/hf_assert_unified_tree.sh أولاً."
  exit 1
fi

QUAR_BASE="$ROOT/legacy"
QUAR_SYM="$QUAR_BASE/symlinks_quarantine"
QUAR_HARD="$QUAR_BASE/hardlinks_quarantine"
mkdir -p "$QUAR_SYM" "$QUAR_HARD"

echo "=================================================="
echo "🧹 HF FIX UNIFIED LINKS"
echo "📄 Log   : $LOG_LATEST"
echo "📂 Root  : $ROOT"
echo "=================================================="

# --- Fix SYMLINKS ---
grep '• SYMLINK:' "$LOG_LATEST" | sed 's/.*SYMLINK: *//' | while read -r P; do
  [[ -z "$P" ]] && continue

  if [[ ! -L "$P" ]]; then
    echo "⚪ تخطي (ليست symlink بعد الآن): $P"
    continue
  fi

  rel="${P#$ROOT/}"
  target="$(readlink -f "$P" || true)"

  echo "🔧 SYMLINK: $P -> $target"

  if [[ -n "$target" && "$target" == "$ROOT"* ]]; then
    # الهدف داخل الهيكل – استبدال symlink بنسخة فعلية
    tmp="${P}.hf_fix_tmp"
    rm -f "$tmp"
    cp -a "$target" "$tmp"
    rm "$P"
    mv "$tmp" "$P"
    echo "✅ تم استبدال symlink بنسخة فعلية (داخل الهيكل): $rel"
  else
    # الهدف خارج /root/HyperFFactory – نقل إلى حجر
    dest="$QUAR_SYM/$rel"
    mkdir -p "$(dirname "$dest")"
    mv "$P" "$dest"
    cat > "$P" <<EOF_NOTE
# تم نقل symlink الأصلي إلى:
#   $dest
# الهدف كان خارج /root/HyperFFactory:
#   $target
# السياسة: يمنع وجود symlink إلى خارج الهيكل الموحّد.
EOF_NOTE
    echo "⚠️ symlink خارجي – نُقل إلى الحجر: $dest"
  fi
done

# --- Fix HARDLINKS ---
grep '• HARDLINK:' "$LOG_LATEST" | sed 's/.*HARDLINK: *//' | while read -r P; do
  [[ -z "$P" ]] && continue

  if [[ ! -f "$P" ]]; then
    echo "⚪ تخطي (الملف غير موجود): $P"
    continue
  fi

  rel="${P#$ROOT/}"
  links="$(stat -c '%h' "$P" 2>/dev/null || echo "1")"

  echo "🔧 HARDLINK: $P (links=$links)"

  if [[ "$links" -gt 1 ]]; then
    tmp="${P}.hf_fix_tmp"
    cp -a "$P" "$tmp"
    mv "$tmp" "$P"
    echo "✅ تم فك hardlink وتحويله لنسخة مستقلة: $rel"
  else
    echo "⚪ تخطي – ليس hardlink فعليًا الآن: $rel"
  fi
done

echo "=================================================="
echo "✅ انتهى hf_fix_unified_links – راجع أي تغييرات في legacy/ وداخل الشجرة."
echo "=================================================="
