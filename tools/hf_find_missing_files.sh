#!/usr/bin/env bash
# HyperFFactory – Server-wide search for important/missing files (parallel, 6 cores)
# - يبحث في كامل السيرفر مع استثناء مسارات النظام/الضوضاء.
# - يستخدم حتى 6 أنوية عبر تشغيل scan_root() بالتوازي.
# - يكتب تقريرًا ضمن هيكل HyperFFactory.

set -Eeuo pipefail

ROOT="/root/HyperFFactory"
REPORT_DIR="$ROOT/reports"
TMP_DIR="$ROOT/tmp"

mkdir -p "$REPORT_DIR" "$TMP_DIR"

TS="$(date +%Y%m%d_%H%M%S)"
LOG="$REPORT_DIR/hf_find_missing_files_${TS}.log"
TMP_RESULTS="$TMP_DIR/find_missing_${TS}.txt"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG"
}

log "=================================================="
log "HyperFFactory – فحص وبحث عن ملفات مفقودة/مهمة (على مستوى السيرفر)"
log "Time  : $TS"
log "Log   : $LOG"
log "Tmp   : $TMP_RESULTS"
log "=================================================="

# الأهداف (أسماء الملفات) – يمكن تمريرها كـ arguments، وإلا نستخدم الافتراضي
if [[ "$#" -gt 0 ]]; then
  TARGETS=("$@")
else
  TARGETS=(
    "run_health.py"
    "sf-service-health"
  )
fi

log "🎯 قائمة الأهداف:"
for t in "${TARGETS[@]}"; do
  log "  - $t"
done

# مسارات مطلقة لا نريد عمل scan لها كجذور + سنستخدمها أيضاً في الـ prune
PRUNE_ABS=(
  "/proc"
  "/sys"
  "/dev"
  "/run"
  "/snap"
  "/lost+found"
  "/var/lib/docker"
  "/var/lib/containerd"
  "/var/lib/snapd"
)

# مسارات نمطية (ضوضاء / مكتبات / كاش) سيتم استبعادها عبر -path
PRUNE_PATTERNS=(
  "*/.git/*"
  "*/venv/*"
  "*/.venv/*"
  "*/env/*"
  "*/__pycache__/*"
  "*/node_modules/*"
)

log "🛡 مسارات سيتم استثناؤها (prune) أثناء البحث:"
for p in "${PRUNE_ABS[@]}"; do
  log "  - ABS : $p"
done
for p in "${PRUNE_PATTERNS[@]}"; do
  log "  - PAT : $p"
done

# بناء ROOTS (كل المجلدات تحت / مع استثناء الجذور الممنوعة)
ROOTS=()
mapfile -t TOPS < <(find / -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort)

for dir in "${TOPS[@]}"; do
  skip=0
  for s in "${PRUNE_ABS[@]}"; do
    if [[ "$dir" == "$s" ]]; then
      skip=1
      break
    fi
  done
  if (( skip )); then
    log "ℹ️ تخطي الجذر (ضمن قائمة الاستثناءات): $dir"
    continue
  fi
  ROOTS+=( "$dir" )
done

if ((${#ROOTS[@]} == 0)); then
  log "❌ لا توجد جذور صالحة للفحص تحت / – إنهاء."
  exit 1
fi

log "📂 جذور البحث (على مستوى السيرفر):"
for r in "${ROOTS[@]}"; do
  log "  - $r"
done

# بناء مصفوفة أسماء الملفات لـ find:  ( -name a -o -name b -o ... )
NAME_ARGS=()
NAME_ARGS+=( "(" )
first=1
for name in "${TARGETS[@]}"; do
  if (( first )); then
    NAME_ARGS+=( -name "$name" )
    first=0
  else
    NAME_ARGS+=( -o -name "$name" )
  fi
done
NAME_ARGS+=( ")" )

# بناء مصفوفة الـ prune: ( -path X -o -path Y -o ... )
PRUNE_ARGS=()
ALL_PRUNE_PATHS=("${PRUNE_ABS[@]}" "${PRUNE_PATTERNS[@]}")
if ((${#ALL_PRUNE_PATHS[@]})); then
  PRUNE_ARGS+=( "(" )
  first=1
  for p in "${ALL_PRUNE_PATHS[@]}"; do
    if (( first )); then
      PRUNE_ARGS+=( -path "$p" )
      first=0
    else
      PRUNE_ARGS+=( -o -path "$p" )
    fi
  done
  PRUNE_ARGS+=( ")" )
fi

scan_root() {
  local root="$1"

  if [[ ! -d "$root" ]]; then
    log "ℹ️ تخطي الجذر غير الموجود: $root"
    return 0
  fi

  log "▶️ بدء الفحص في: $root"

  if ((${#PRUNE_ARGS[@]})); then
    find "$root" "${PRUNE_ARGS[@]}" -prune -o -type f "${NAME_ARGS[@]}" -print 2>/dev/null \
      | while read -r path; do
          local base
          base="$(basename "$path")"
          printf '%s|%s\n' "$base" "$path" >> "$TMP_RESULTS"
          log "🔎 FOUND: $path"
        done
  else
    find "$root" -type f "${NAME_ARGS[@]}" -print 2>/dev/null \
      | while read -r path; do
          local base
          base="$(basename "$path")"
          printf '%s|%s\n' "$base" "$path" >> "$TMP_RESULTS"
          log "🔎 FOUND: $path"
        done
  fi

  log "✅ انتهى الفحص في: $root"
}

# شريط التقدّم
BAR_WIDTH=40
TOTAL=${#ROOTS[@]}
COMPLETED=0

update_bar() {
  local done="$1"
  local total="$2"
  local filled=$(( done * BAR_WIDTH / total ))
  local empty=$(( BAR_WIDTH - filled ))
  local bar_filled
  local bar_empty
  bar_filled=$(printf "%${filled}s" | tr ' ' '#')
  bar_empty=$(printf "%${empty}s")
  printf "\r[%-*s] %d/%d جذور مكتملة" "$BAR_WIDTH" "${bar_filled}${bar_empty}" "$done" "$total" | tee -a "$LOG" >/dev/null
}

log "🧵 بدء تشغيل الفحص على الجذور (parallel بحد أقصى 6 أنوية)"

active_jobs=0

for root in "${ROOTS[@]}"; do
  # لو فيه 6 jobs شغّالة، انتظر Job واحد يخلّص
  while (( active_jobs >= 6 )); do
    if wait -n 2>/dev/null; then
      ((COMPLETED++))
      ((active_jobs--))
      update_bar "$COMPLETED" "$TOTAL"
    else
      ((COMPLETED++))
      ((active_jobs--))
      update_bar "$COMPLETED" "$TOTAL"
    fi
  done

  scan_root "$root" &
  ((active_jobs++))
done

# انتظار باقي الـ jobs
while (( active_jobs > 0 )); do
  if wait -n 2>/dev/null; then
    ((COMPLETED++))
    ((active_jobs--))
    update_bar "$COMPLETED" "$TOTAL"
  else
    ((COMPLETED++))
    ((active_jobs--))
    update_bar "$COMPLETED" "$TOTAL"
  fi
done

echo "" | tee -a "$LOG"
log "🧮 الفحص على مستوى الجذور انتهى."

log "=================================================="
log "📊 ملخص النتائج حسب الاسم"
log "=================================================="

if [[ ! -s "$TMP_RESULTS" ]]; then
  log "❌ لم يتم العثور على أي من الأهداف في كل السيرفر (مع الاستثناءات المحددة)."
  for t in "${TARGETS[@]}"; do
    log "   - $t : MISSING"
  done
else
  log "📌 جميع النتائج (base|path):"
  sort "$TMP_RESULTS" | while IFS='|' read -r base path; do
    log "   - $base -> $path"
  done

  log "--------------------------------------------------"
  log "📈 عدد النتائج لكل اسم:"
  awk -F'|' '{cnt[$1]++} END {for (k in cnt) printf "   - %s : %d\n", k, cnt[k]}' "$TMP_RESULTS" | tee -a "$LOG"

  for t in "${TARGETS[@]}"; do
    if ! grep -q "^${t}|" "$TMP_RESULTS"; then
      log "   - $t : MISSING"
    fi
  done
fi

log "=================================================="
log "DONE – hf_find_missing_files (server-wide) انتهى"
log "Report: $LOG"
log "=================================================="
