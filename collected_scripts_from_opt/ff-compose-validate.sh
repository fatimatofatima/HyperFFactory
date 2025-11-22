#!/usr/bin/env bash
set -Eeuo pipefail
base="/opt/ffactory/stack"
echo "فحص ملفات compose في: $base"
ok=0; bad=0; skipped=0
while IFS= read -r -d '' f; do
  [[ ! -s "$f" ]] && { echo "تخطي (فارغ): $f"; ((skipped++)); continue; }
  if ! grep -Eq '^\s*services\s*:' "$f"; then
    echo "تخطي (ليس compose): $f"; ((skipped++)); continue;
  fi
  if docker compose -f "$f" config >/dev/null 2>&1; then
    echo "✅ OK: $f"; ((ok++))
  else
    echo "❌ ERROR: $f"; ((bad++))
  fi
done < <(find "$base" -maxdepth 2 -type f -name "*.yml" -print0)
echo "النتيجة: OK=$ok, ERROR=$bad, SKIPPED=$skipped"
[[ $bad -eq 0 ]]
