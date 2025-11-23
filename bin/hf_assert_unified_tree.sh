#!/usr/bin/env bash
set -euo pipefail

ROOT="/root/HyperFFactory"
cd "$ROOT"

LOG_DIR="$ROOT/reports"
mkdir -p "$LOG_DIR"
TS="$(date '+%Y%m%d_%H%M%S')"
LOG_FILE="$LOG_DIR/hf_assert_unified_tree_${TS}.log"

log() {
  echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "============================================================"
log "🛠 HyperFFactory – Assert Unified Tree Policy (Smart Mode)"
log "ROOT : $ROOT"
log "LOG  : $LOG_FILE"
log "============================================================"
log "INFO: بدء فحص symlinks داخل $ROOT (بدون الخروج إلى نظام الملفات العام إلا للتكامل المسموح)."

errors=0

# استثناء: links زي ops/ops أو apps/apps داخل الشجرة
is_internal_name_exception() {
  local link_path="$1"
  case "$link_path" in
    "$ROOT/ops/ops"|"$ROOT/apps/apps")
      return 0;;
  esac
  return 1
}

# استثناء: venv/bin/python* → /usr/bin/python*
is_allowed_python_link() {
  local link_path="$1"
  local target="$2"
  case "$link_path" in
    */venv*/bin/python|*/venv*/bin/python3|*/venv*/bin/python3.10|*/.venv/bin/python|*/.venv/bin/python3|*/.venv/bin/python3.10)
      case "$target" in
        /usr/bin/python3|/usr/bin/python3.10|/usr/bin/python3.*)
          return 0;;
      esac
    ;;
  esac
  return 1
}

# استثناء: motd/landscape snapshots داخل motd_backup*
is_motd_landscape_link() {
  local target="$1"
  case "$target" in
    /usr/share/landscape/landscape-sysinfo.wrapper)
      return 0;;
  esac
  return 1
}

# استثناء: systemd symlinks داخل لقطات root legacy فقط (NOT runtime حالي)
# مثال: /root/HyperFFactory/opt/_root_legacy_.../sf_backup_.../sf-*.service → /etc/systemd/system/sf-*.service
is_legacy_systemd_snapshot() {
  local link_path="$1"
  local target="$2"

  case "$link_path" in
    "$ROOT"/opt/_root_legacy_*/*/sf-*.service|\
    "$ROOT"/opt/_root_legacy_*/*/*.target.wants/sf-*.service)
      case "$target" in
        /etc/systemd/system/sf-*.service)
          return 0;;
      esac
    ;;
  esac

  return 1
}

log "INFO: فحص symlinks ..."

while IFS= read -r -d '' link; do
  target="$(readlink "$link" || true)"

  if [[ -z "$target" ]]; then
    log "WARN: symlink تالف (لا يمكن resolve): $link"
    continue
  fi

  real="$(readlink -f "$link" 2>/dev/null || true)"
  [[ -n "$real" ]] && target="$real"

  # 1) داخل الشجرة مباشرة
  if [[ "$target" == "$ROOT"* ]]; then
    log "OK  : symlink داخل الشجرة: $link → $target"
    continue
  fi

  # 2) استثناءات بالأسماء (ops/ops, apps/apps, إلخ)
  if is_internal_name_exception "$link"; then
    log "OK  : symlink داخلي مستثنى بالاسم: $link → $target"
    continue
  fi

  # 3) استثناء venv python → /usr/bin/python*
  if is_allowed_python_link "$link" "$target"; then
    log "OK  : symlink تكامل/استثناء مسموح (venv python): $link → $target"
    continue
  fi

  # 4) استثناء motd → landscape-sysinfo.wrapper
  if is_motd_landscape_link "$target"; then
    log "OK  : symlink تكامل/استثناء مسموح (motd/landscape): $link → $target"
    continue
  fi

  # 5) استثناء legacy systemd snapshot (لقطات /opt/_root_legacy_* فقط)
  if is_legacy_systemd_snapshot "$link" "$target"; then
    log "OK  : symlink لقطة legacy systemd (snapshot فقط – غير فعّال): $link → $target"
    continue
  fi

  # 6) أي شيء آخر خارج الشجرة يعتبر تهريب حقيقي
  log "ERROR: Escape symlink (تهريب خارج الشجرة): $link → $target"
  errors=$((errors+1))
done < <(find "$ROOT" -xtype l -print0 2>/dev/null)

if (( errors > 0 )); then
  log "============================================================"
  log "❌ فشل السياسة: تم العثور على ${errors} symlink من نوع Escape تحتاج مراجعة يدوية."
  exit 1
else
  log "============================================================"
  log "✅ السياسة سليمة: لا توجد symlinks تهريب خارج الشجرة (مع استثناءات التكامل واللقطات المسموح بها)."
  exit 0
fi
