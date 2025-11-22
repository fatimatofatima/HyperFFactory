#!/usr/bin/env bash
set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "[SECURITY] HyperFFactory security_autofix (project-local only)"

# تشديد صلاحيات مجلد audit
if [[ -d "${ROOT_DIR}/audit" ]]; then
  chmod -R go-rwx "${ROOT_DIR}/audit"
  echo "  - audit perms hardened."
fi

# تشديد صلاحيات السكربتات
find "${ROOT_DIR}/scripts" -type f -name "*.sh" -exec chmod u+x {} \; -exec chmod go-rwx {} \; 2>/dev/null || true
echo "  - scripts perms tightened (u+x, go-rwx)."

echo "[SECURITY] Done (no system-wide changes)."
