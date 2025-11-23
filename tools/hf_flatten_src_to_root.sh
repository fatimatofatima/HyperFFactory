#!/usr/bin/env bash
set -euo pipefail

ROOT="/root/HyperFFactory"
SRC="$ROOT/src"

echo "===== HyperFFactory – Flatten SRC into ROOT ====="
date
echo "ROOT : $ROOT"
echo "SRC  : $SRC"
echo

if [ ! -d "$ROOT" ]; then
  echo "!! ROOT directory not found: $ROOT"
  exit 1
fi

if [ ! -d "$SRC" ]; then
  echo ">> SRC directory not found, nothing to flatten."
  echo "===== DONE (NO SRC) ====="
  exit 0
fi

TS=$(date +%Y%m%d_%H%M%S)
BACKUP_ROOT="$ROOT/_root_conflicts_$TS"
LEGACY_SRC="$ROOT/_src_legacy_$TS"

mkdir -p "$BACKUP_ROOT"

echo "== Before =="
ls -la "$ROOT"
echo
echo "== SRC content (level 1) =="
ls -la "$SRC"
echo

# 1) نقل ملفات المستوى الأعلى من src إلى الجذر (apps.py / ops.py)
for f in apps.py ops.py; do
  if [ -f "$SRC/$f" ]; then
    if [ -f "$ROOT/$f" ]; then
      echo "!! Conflict on $f – moving existing ROOT file to backup."
      mv "$ROOT/$f" "$BACKUP_ROOT/$f"
    fi
    echo ">> Moving $SRC/$f -> $ROOT/$f"
    mv "$SRC/$f" "$ROOT/$f"
  fi
done

# 2) نقل مجلدات الكود الرئيسية من src إلى الجذر (apps / hyper_factory / ops)
for d in apps hyper_factory ops; do
  if [ -d "$SRC/$d" ]; then
    if [ -d "$ROOT/$d" ]; then
      echo "!! Conflict on dir $d – moving existing ROOT dir to backup."
      mv "$ROOT/$d" "$BACKUP_ROOT/$d"
    fi
    echo ">> Moving dir $SRC/$d -> $ROOT/$d"
    mv "$SRC/$d" "$ROOT/$d"
  fi
done

# 3) تحويل src إلى legacy (إلغاء مسمى src من الاستخدام اليومي)
echo
echo ">> Renaming SRC to legacy holder: $LEGACY_SRC"
mv "$SRC" "$LEGACY_SRC"

echo
echo "== After =="
ls -la "$ROOT"
echo
echo "== New top-level code layout =="
ls -la "$ROOT/apps" 2>/dev/null || echo "(no apps/ dir)"
ls -la "$ROOT/hyper_factory" 2>/dev/null || echo "(no hyper_factory/ dir)"
ls -la "$ROOT/ops" 2>/dev/null || echo "(no ops/ dir)"
echo
echo "Legacy SRC stored at: $LEGACY_SRC"
echo "Any conflicts stored at: $BACKUP_ROOT"
echo
echo "===== DONE – ROOT is now the only active code root ====="
