#!/usr/bin/env bash
set -Eeuo pipefail

JOBS="${JOBS:-6}"
REMOTE="${REMOTE:-git@github.com:fatimatofatima/ffactory.git}"
AUTHOR_NAME="${AUTHOR_NAME:-Fatimatofatima}"
AUTHOR_EMAIL="${AUTHOR_EMAIL:-Fatimatofatima988@gmail.com}"
BRANCH="${BRANCH:-code-snapshot-RESUME-$(date +%Y%m%d_%H%M)}"

RUN="$(ls -dt /root/export_sh_py_* | head -1)"
DEST="$RUN/snapshot"
MAN="$RUN/manifest.csv"
TMP="$RUN/.manifest.tmp"

echo "[R] Rebuilding manifest for: $RUN"
rm -f "$TMP" "$MAN"
printf "path,size,mtime_epoch,sha256\n" > "$MAN"
export DEST
find "$DEST" -type f \( -name '*.sh' -o -name '*.py' \) -print0 \
| xargs -0 -P "$JOBS" -n1 bash -c '
  dest="$0"; f="$1"
  [ -f "$f" ] || exit 0
  rel="${f#"$dest/"}"
  size=$(stat -c%s "$f" 2>/dev/null || echo 0)
  mtime=$(stat -c%Y "$f" 2>/dev/null || echo 0)
  sum=$(sha256sum -b "$f" 2>/dev/null | cut -d" " -f1 || echo 0)
  printf "%s,%s,%s,%s\n" "$rel" "$size" "$mtime" "$sum"
' "$DEST" _ > "$TMP"
sort "$TMP" >> "$MAN"; rm -f "$TMP"

echo "[R] Git commit & push..."
cd "$DEST"
if [ ! -d .git ]; then
  git init -q
  git config user.name  "$AUTHOR_NAME"
  git config user.email "$AUTHOR_EMAIL"
fi
git add -A
git commit -m "Snapshot resume + manifest rebuilt @ $(date +%F\ %T)" || true
git branch -M "$BRANCH"

if git remote get-url origin >/dev/null 2>&1; then
  git remote set-url origin "$REMOTE"
else
  git remote add origin "$REMOTE"
fi

# تقليل استهلاك الذاكرة وحجم الحِزم
git config pack.windowMemory 100m
git config pack.packSizeLimit 100m
git config pack.threads 1

GIT_SSH_COMMAND="ssh -o TCPKeepAlive=yes -o ServerAliveInterval=30" \
git push -u origin "$BRANCH"
echo "[R] Done."
