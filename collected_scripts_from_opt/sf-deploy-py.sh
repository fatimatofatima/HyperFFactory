#!/usr/bin/env bash
set -Eeuo pipefail
SRC="${1:?SRC}"
DST="${2:?DST}"
VENV="${3:-/opt/smartfrind/venv}"
APPD="${4:-/opt/smartfrind/app}"

TMP="$(mktemp "${DST}.XXXX")"
install -m 640 "$SRC" "$TMP"
PYTHONPATH="$APPD" "$VENV/bin/python" -m py_compile "$TMP"
install -m 640 "$TMP" "$DST"
rm -f "$TMP"
echo "[deploy] $(basename "$DST") done"
