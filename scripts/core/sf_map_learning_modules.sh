#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="/opt/smartfrind"
TS="$(date +%Y%m%d_%H%M%S)"
OUT_DIR="/root/sf_reports"
OUT="${OUT_DIR}/learning_map_${TS}.txt"
mkdir -p "$OUT_DIR"

teeout(){ tee -a "$OUT" >/dev/null; }

echo "===================================================" | teeout
echo "   🧠 SmartFrind - Learning & Spider Modules Map"   | teeout
echo "   Time: $(date)"                                   | teeout
echo "   Root: ${ROOT}"                                  | teeout
echo "===================================================" | teeout
echo | teeout

if [ ! -d "$ROOT" ]; then
  echo "[✗] Root directory not found: $ROOT" | teeout
  exit 1
fi

# ---------------- 1) ملفات معروفة من الأسماء ----------------
echo "1) 🔎 Top-level learning-related files (name-based)" | teeout

find "$ROOT" -maxdepth 1 -type f -iname "*.py" \
  \( -iname "learn_*.py" -o -iname "*learn*.py" -o -iname "*knowledge*.py" -o -iname "*curriculum*.py" \) \
  -printf "   📄 %P\n" 2>/dev/null | teeout || true

echo | teeout
echo "2) 🧬 Learner / Neural / Spider dirs & files (name-based)" | teeout

NAME_PATTERNS=(
  "*learn*"
  "*learning*"
  "*knowledge*"
  "*curriculum*"
  "*neural*"
  "*net_learner*"
  "*learner*"
  "*spider*"
  "*crawler*"
  "*crawl*"
)

for pat in "${NAME_PATTERNS[@]}"; do
  echo | teeout
  echo "   ▸ Pattern: $pat" | teeout
  find "$ROOT" -type f -iname "$pat" -printf "      %P\n" 2>/dev/null | teeout || true
done

# ---------------- 3) فحص المحتوى داخل ملفات بايثون/شيل ----------------
echo | teeout
echo "3) 📑 Content scan for learning / spider keywords" | teeout

CONTENT_PATTERNS='learn_from|auto[_-]?learning|online[_-]?learning|train_loop|trainer|knowledge[_-]?base|curriculum|neural|net_learner|Spider|spider|crawler|crawl[_a-z]*\(|smartspider'

find "$ROOT" \
  -type f \
  \( -iname "*.py" -o -iname "*.sh" -o -iname "*.service" -o -iname "*.timer" \) \
  -size -1048576c \
  -print0 2>/dev/null \
| xargs -0 -r grep -i -n -E "$CONTENT_PATTERNS" 2>/dev/null \
| sed 's/^/   🔹 /' \
| teeout || true

# ---------------- 4) systemd units المرتبطة بـ smartfrind ----------------
echo | teeout
echo "4) ⚙️ systemd units that may involve learning/spider" | teeout

SYSTEMD_DIRS=(
  "/etc/systemd/system"
  "/lib/systemd/system"
)

for d in "${SYSTEMD_DIRS[@]}"; do
  [ -d "$d" ] || continue
  echo | teeout
  echo "   📁 $d" | teeout
  ls "$d" 2>/dev/null | grep -Ei 'smartfrind|smartfriend|learn|spider|crawler|neural' \
    | sed 's/^/      unit: /' \
    | teeout || true

  find "$d" -type f \( -iname "*.service" -o -iname "*.timer" \) 2>/dev/null \
    | xargs -r grep -i -n -E "$CONTENT_PATTERNS" 2>/dev/null \
    | sed 's/^/      match: /' \
    | teeout || true
done

echo | teeout
echo "===================================================" | teeout
echo "   ✅ Map finished. Report: ${OUT}"                  | teeout
echo "===================================================" | teeout
