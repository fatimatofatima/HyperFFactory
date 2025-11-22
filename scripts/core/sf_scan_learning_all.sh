#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
OUT_DIR="/root/sf_reports"
OUT="${OUT_DIR}/learning_scan_${TS}.txt"
mkdir -p "$OUT_DIR"

teeout(){ tee -a "$OUT" >/dev/null; }

echo "===============================================" | teeout
echo "   🔍 SmartFrind - Learning & Spider Scan" | teeout
echo "   Time: $(date)" | teeout
echo "===============================================" | teeout
echo | teeout

SEARCH_ROOTS=(
  "/root"
  "/opt"
  "/srv"
)

NAME_PATTERNS=(
  "*learn*"
  "*learning*"
  "*auto_learning*"
  "*trainer*"
  "*training*"
  "*neural*"
  "*neuron*"
  "*spider*"
  "*crawler*"
  "*smartspider*"
)

CONTENT_PATTERNS='learning|auto_learning|train_loop|trainer|self[_-]?learn|online[_-]?learning|neural|spider|crawler|smartspider'

echo "1) 🔎 الملفات المشتبه بها بالاسم (learning / spider / neural ...)" | teeout
for root in "${SEARCH_ROOTS[@]}"; do
  [ -d "$root" ] || continue
  echo | teeout
  echo "   📂 Root: $root" | teeout
  for pat in "${NAME_PATTERNS[@]}"; do
    find "$root" -type f -iname "$pat" -printf '      %p\n' 2>/dev/null | teeout || true
  done
done

echo | teeout
echo "2) 📑 البحث داخل الملفات (محتوى) عن كلمات التعلم والسبايدر" | teeout
for root in "${SEARCH_ROOTS[@]}"; do
  [ -d "$root" ] || continue
  echo | teeout
  echo "   📂 Root (content scan): $root" | teeout

  find "$root" \
    -type f \
    \( -iname "*.py" -o -iname "*.sh" -o -iname "*.service" -o -iname "*.timer" -o -iname "*.env" -o -iname "*.ini" -o -iname "*.yml" -o -iname "*.yaml" \) \
    -size -5M \
    -print0 2>/dev/null \
  | xargs -0 -r grep -i -n -E "$CONTENT_PATTERNS" 2>/dev/null \
  | sed 's/^/      /' \
  | teeout || true
done

echo | teeout
echo "3) ⚙️  systemd units المتعلقة بالتعلّم / السبايدر" | teeout

SYSTEMD_DIRS=(
  "/etc/systemd/system"
  "/lib/systemd/system"
)

for d in "${SYSTEMD_DIRS[@]}"; do
  [ -d "$d" ] || continue
  echo | teeout
  echo "   📁 $d" | teeout
  ls "$d" 2>/dev/null | grep -Ei 'learn|auto[_-]?learn|trainer|neural|spider|crawler|smartfrind|smartfriend' \
    | sed 's/^/      unit: /' \
    | teeout || true

  find "$d" -type f -iname "*.service" -o -iname "*.timer" 2>/dev/null \
    | xargs -r grep -i -n -E "$CONTENT_PATTERNS" 2>/dev/null \
    | sed 's/^/      match: /' \
    | teeout || true
done

echo | teeout
echo "4) ⏰ فحص الـ cron jobs (root + system)" | teeout

echo | teeout
echo "   🔹 root crontab:" | teeout
crontab -l 2>/dev/null \
  | grep -Ei 'learn|trainer|neural|spider|crawler' \
  | sed 's/^/      /' \
  | teeout || echo "      (لا توجد مدخلات متعلقة بالتعلّم في crontab root)" | teeout

for d in /etc/cron.d /etc/cron.daily /etc/cron.hourly /etc/cron.weekly /etc/cron.monthly; do
  [ -d "$d" ] || continue
  echo | teeout
  echo "   📁 $d" | teeout
  grep -R -i -n -E 'learn|trainer|neural|spider|crawler' "$d" 2>/dev/null \
    | sed 's/^/      /' \
    | teeout || true
done

echo | teeout
echo "===============================================" | teeout
echo "   ✅ Scan finished. Report: $OUT" | teeout
echo "===============================================" | teeout
