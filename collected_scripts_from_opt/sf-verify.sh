#!/usr/bin/env bash
set -Eeuo pipefail
APP=smartfrind
ROOT=/opt/$APP
APPD="$ROOT/app"
PKG="$APPD/$APP"
VENV="$ROOT/venv"
ETC="/etc/$APP"

err(){ echo "[verify][ERROR] $*" >&2; exit 1; }

[ -r "$ETC/config.env" ] || err "config.env غير موجود"
API_KEY="$(grep -E '^SMARTFRIND_API_KEY=' "$ETC/config.env" | cut -d= -f2- || true)"
[ -n "$API_KEY" ] || err "SMARTFRIND_API_KEY فارغ/مفقود"
JWT_PATH="$(grep -E '^JWT_SECRET_PATH=' "$ETC/config.env" | cut -d= -f2- || echo '/var/lib/smartfrind/secret.key')"
[ -s "$JWT_PATH" ] || err "JWT_SECRET_PATH مفقود أو فارغ"
[ -x "$VENV/bin/python" ] || err "venv python مفقود"
[ -f "$PKG/gateway_secure.py" ] || err "gateway_secure.py مفقود"
PYTHONPATH="$APPD" "$VENV/bin/python" -m py_compile "$PKG/gateway_secure.py" || err "فشل compile لـ gateway_secure.py"
exit 0
