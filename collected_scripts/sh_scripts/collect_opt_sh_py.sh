#!/usr/bin/env bash
set -Eeuo pipefail

BASE_SRC="/opt"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
DEST_BASE="/opt/COMPLETE_CODE_BACKUP"
DEST="${DEST_BASE}/sh_py_snapshot_${TIMESTAMP}"

mkdir -p "$DEST"

cd "$BASE_SRC"

dirs=(
  "BRAIN_CORE"
  "containerd"
  "deepseek"
  "ffactory"
  "MyFriend"
  "portsboard"
  "SmartFriend"
  "smartfriend-suite"
  "smartfrind"
  "SmartFrind_Miracle"
  "smartfrind_unified"
  "ULTIMATE_FUSION"
)

echo ">>> جمع ملفات .sh و .py ..."
for d in "${dirs[@]}"; do
  if [ -d "$d" ]; then
    echo ">>> Scanning: $d"
    find "$d" -type f \( -name '*.sh' -o -name '*.py' \) -print |
    while IFS= read -r f; do
      target_dir="${DEST}/$(dirname "$f")"
      mkdir -p "$target_dir"
      cp -a "$f" "$target_dir/"
    done
  else
    echo "!!! Skipping (not found): $d"
  fi
done

echo
echo ">>> ضغط كل مجلد بشكل منفصل داخل مجلد الجمع ..."
cd "$DEST"

for d in "${dirs[@]}"; do
  if [ -d "$d" ]; then
    tar_name="${d}.tar.gz"
    echo "  - Archiving $d -> $tar_name"
    tar -czf "$tar_name" "$d"
  fi
done

echo
echo ">>> إنشاء أرشيف موحّد لكل الملفات المضغوطة ..."
MASTER_ARCHIVE="${DEST_BASE}/sh_py_archives_${TIMESTAMP}.tar.gz"
tar -czf "$MASTER_ARCHIVE" ./*.tar.gz

echo
echo "Snapshot root: $DEST"
echo "Per-folder archives inside snapshot:"
ls -1 *.tar.gz 2>/dev/null || echo "No per-folder archives found."

echo
echo "Unified archive created:"
echo "  $MASTER_ARCHIVE"
