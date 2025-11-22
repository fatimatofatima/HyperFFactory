#!/usr/bin/env bash
set -euo pipefail
SRC="${1:-}"; OUT="${2:-}"; COOKIES="${3:-}"
if [[ -z "${SRC}" ]]; then
  echo "usage: $0 <url|/path/file.html> [out.pdf] [cookies.txt]" >&2; exit 1
fi
OUT="${OUT:-$PWD/$(date +%F_%H%M)_export.pdf}"
mkdir -p "$(dirname "$OUT")"

have(){ command -v "$1" >/dev/null 2>&1; }

render_with_wkhtml(){
  local args=(--enable-local-file-access --print-media-type --page-size A4
              --margin-top 10mm --margin-bottom 10mm --margin-left 10mm --margin-right 10mm
              --dpi 110)
  if [[ -n "${COOKIES:-}" && -f "$COOKIES" ]]; then
    while IFS=$'\t' read -r domain flag path secure expiry name value; do
      [[ -z "${name:-}" || "${name:0:1}" == "#" ]] && continue
      args+=( --cookie "$name" "$value" )
    done < "$COOKIES"
  fi
  wkhtmltopdf "${args[@]}" "$SRC" "$OUT"
}

render_with_chrome(){
  local CHROME="$(command -v chromium || command -v chromium-browser || command -v google-chrome || command -v google-chrome-stable || true)"
  [[ -n "$CHROME" ]] || { echo "Chrome/Chromium غير موجود" >&2; return 1; }
  "$CHROME" --headless --disable-gpu --no-sandbox --print-to-pdf="$OUT" "$SRC"
}

if have wkhtmltopdf; then render_with_wkhtml
else render_with_chrome
fi

[[ -s "$OUT" ]] || { echo "[ERR] فشل التصدير" >&2; exit 2; }
echo "[OK] $OUT"
