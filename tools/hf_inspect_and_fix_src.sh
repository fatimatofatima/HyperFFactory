#!/usr/bin/env bash
set -euo pipefail

ROOT="/root/HyperFFactory"
SRC_DIR="$ROOT/src"

echo "===== HyperFFactory – SRC Inspection & Fix (safe) ====="
date
echo "ROOT: $ROOT"
echo "SRC : $SRC_DIR"
echo

if [ ! -d "$SRC_DIR" ]; then
  echo "!! SRC directory not found: $SRC_DIR"
  exit 1
fi

echo "== ls -la \$SRC_DIR =="
ls -la "$SRC_DIR"
echo

echo "== Symlinks under src (maxdepth 2) =="
find "$SRC_DIR" -maxdepth 2 -xtype l -printf '%p -> %l\n' 2>/dev/null || true
echo

TMP_SYMS="$(mktemp)"
TMP_BAD="$(mktemp)"

# نجمع كل الروابط الرمزية تحت src
find "$SRC_DIR" -maxdepth 2 -xtype l -print 2>/dev/null > "$TMP_SYMS" || true

if ! [ -s "$TMP_SYMS" ]; then
  echo ">> No symlinks found under src. Nothing to fix."
  rm -f "$TMP_SYMS" "$TMP_BAD"
  echo "===== DONE (INSPECT ONLY) ====="
  exit 0
fi

echo "== Checking for symlinks escaping \$ROOT =="
while IFS= read -r SYM_PATH; do
  [ -z "\$SYM_PATH" ] && continue
  if RESOLVED_FULL=\$(readlink -f "\$SYM_PATH" 2>/dev/null); then
    RESOLVED="\$RESOLVED_FULL"
  else
    RESOLVED=""
  fi

  if [ -n "\$RESOLVED" ] && [[ "\$RESOLVED" == \$ROOT* ]]; then
    # داخل جذر المشروع → لا مشكلة
    :
  else
    echo "!! Symlink escapes ROOT or unresolved:"
    echo "   \$SYM_PATH -> \$RESOLVED"
    echo "\$SYM_PATH" >> "\$TMP_BAD"
  fi
done < "$TMP_SYMS"
echo

if ! [ -s "$TMP_BAD" ]; then
  echo ">> All symlinks under src resolve inside \$ROOT. Nothing to fix."
  rm -f "$TMP_SYMS" "$TMP_BAD"
  echo "===== DONE (INSPECT ONLY) ====="
  exit 0
fi

echo "== Problematic symlinks under src =="
cat "$TMP_BAD"
echo

echo "هذا السكربت سيقوم بالآتي عند الموافقة:"
echo "1) نقل كل symlink مشكلة إلى ملف احتياطي بنفس الاسم + suffix تاريخ."
echo "2) عدم حذف أي ملفات هدف أو أرشيف."
echo
read -rp "تأكيد تنفيذ التصحيح؟ (y/N): " ans
case "\$ans" in
  y|Y)
    ;;
  *)
    echo ">> Skipping fix by user choice."
    rm -f "$TMP_SYMS" "$TMP_BAD"
    echo "===== DONE (INSPECT ONLY) ====="
    exit 0
    ;;
esac

TS=\$(date +%Y%m%d_%H%M%S)

while IFS= read -r SYM_PATH; do
  [ -z "\$SYM_PATH" ] && continue
  if [ -L "\$SYM_PATH" ]; then
    BACKUP="\${SYM_PATH}_legacy_\$TS"
    echo "Moving symlink: \$SYM_PATH -> \$BACKUP"
    mv "\$SYM_PATH" "\$BACKUP"
  fi
done < "$TMP_BAD"

rm -f "$TMP_SYMS" "$TMP_BAD"

echo
echo "== SRC after fix =="
ls -la "$SRC_DIR"
echo
echo "===== DONE (INSPECT + FIX SYMLINKS ONLY) ====="
