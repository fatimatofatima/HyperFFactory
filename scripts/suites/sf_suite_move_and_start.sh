#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

TS="$(date +%Y%m%d_%H%M%S)"

BLUE='\033[0;34m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log()    { echo -e "${BLUE}[$(date '+%F %T')]${NC} $*"; }
warn()   { echo -e "${YELLOW}[$(date '+%F %T')] [WARN]${NC} $*" >&2; }
error()  { echo -e "${RED}[$(date '+%F %T')] [ERROR]${NC} $*" >&2; }
success(){ echo -e "${GREEN}[$(date '+%F %T')] [OK]${NC} $*"; }

CANON_DB="/opt/smartfriend-suite/var/db/smartfriend_unified.db"
LEGACY_DBS=(
  "/opt/smartfriend-suite/data/db/smartfriend_unified.db"
  "/opt/smartfriend-suite/data/smartfriend_unified.db"
)

ensure_root() {
  if [[ "$EUID" -ne 0 ]]; then
    error "السكربت يحتاج root."
    exit 1
  fi
}

check_canon_db() {
  log "=== [1] التحقق من القاعدة الرسمية للسيويت ==="
  if [[ ! -f "$CANON_DB" ]]; then
    error "ملف القاعدة غير موجود: $CANON_DB"
    error "لو في نسخة أخرى للـ DB لازم نحددها يدويًا قبل المتابعة."
    exit 1
  fi
  ls -lh "$CANON_DB" || true
  success "القاعدة الرسمية موجودة."
}

fix_legacy_db_paths() {
  log "=== [2] إزالة أي symlink للـ DB واستبداله بـ hardlink (بدون لمس ffactory) ==="
  for path in "${LEGACY_DBS[@]}"; do
    dir="$(dirname "$path")"
    [[ -d "$dir" ]] || mkdir -p "$dir"

    if [[ -L "$path" ]]; then
      # كان symlink – نحذف ونستبدل بـ hardlink
      warn "المسار كان symlink: $path – سيتم استبداله بـ hardlink."
      rm -f "$path"
      ln "$CANON_DB" "$path"
      success "تم إنشاء hardlink: $path -> $CANON_DB"
    elif [[ -e "$path" ]]; then
      # ملف عادي قديم – نأرشفه ثم نعمل hardlink
      warn "المسار موجود كملف عادي: $path – سيتم أرشفته وإنشاء hardlink جديد."
      mv "$path" "${path}.bak_${TS}"
      ln "$CANON_DB" "$path"
      success "تم إنشاء hardlink جديد: $path -> $CANON_DB (القديم في ${path}.bak_${TS})"
    else
      # غير موجود – ننشئ hardlink جديد
      log "إنشاء hardlink جديد للمسار: $path"
      ln "$CANON_DB" "$path"
      success "تم إنشاء hardlink: $path -> $CANON_DB"
    fi
  done
}

list_suite_units() {
  log "=== [3] رصد وحدات systemd الخاصة بالسيويت (sf-* و smartfriend-*) ==="
  # نجيب كل الوحدات sf-*.service
  mapfile -t SF_UNITS < <(systemctl list-unit-files 'sf-*.service' --no-legend 2>/dev/null | awk '{print $1}' | sort -u)
  mapfile -t SF_UNITS_ACTIVE < <(systemctl list-units 'sf-*.service' --all --no-legend 2>/dev/null | awk '{print $1}' | sort -u)

  # نجيب كل الوحدات smartfriend-*.service
  mapfile -t SFRIEND_UNITS < <(systemctl list-unit-files 'smartfriend-*.service' --no-legend 2>/dev/null | awk '{print $1}' | sort -u)
  mapfile -t SFRIEND_UNITS_ACTIVE < <(systemctl list-units 'smartfriend-*.service' --all --no-legend 2>/dev/null | awk '{print $1}' | sort -u)

  log "--- وحدات sf-*.service (حسب unit-files) ---"
  if ((${#SF_UNITS[@]})); then
    printf '  %s\n' "${SF_UNITS[@]}"
  else
    warn "لا توجد وحدات sf-*.service معرفة (unit-files)."
  fi

  log "--- وحدات smartfriend-*.service (حسب unit-files) ---"
  if ((${#SFRIEND_UNITS[@]})); then
    printf '  %s\n' "${SFRIEND_UNITS[@]}"
  else
    warn "لا توجد وحدات smartfriend-*.service معرفة (unit-files)."
  fi

  # نخزن في متغيرات global ليستخدمها جزء التشغيل
  ALL_SUITE_UNITS=("${SF_UNITS[@]}" "${SFRIEND_UNITS[@]}")
}

start_unit_safe() {
  local unit="$1"
  if [[ -z "$unit" ]]; then
    return
  fi

  # تجاهل أي شيء فيه ffactory أو يبدأ بـ ff-
  if [[ "$unit" == ff-* ]] || [[ "$unit" == *ffactory* ]]; then
    warn "تخطي وحدة خاصة بـ ffactory: $unit (لن يتم لمسها)."
    return
  fi

  # تجاهل SmartFrind (smartfrind-*) في هذا السكربت
  if [[ "$unit" == smartfrind-* ]]; then
    warn "تخطي وحدة SmartFrind: $unit (خارج نطاق السيويت في هذا السكربت)."
    return
  fi

  # نتأكد أنها معرّفة كملف وحدة
  if ! systemctl list-unit-files "$unit" --no-legend &>/dev/null; then
    warn "الوحدة غير معرّفة كملف systemd: $unit – سيتم تجاهلها."
    return
  fi

  log "تشغيل / إعادة تشغيل الوحدة: $unit"
  if systemctl restart "$unit"; then
    success "تم تشغيل الوحدة بنجاح: $unit"
  else
    warn "فشل تشغيل الوحدة: $unit – راجع logs عبر: journalctl -u $unit -n 50 --no-pager"
  fi
}

start_suite_core() {
  log "=== [4] تشغيل طبقة Core الأساسية للسيويت أولاً ==="
  local CORE_UNITS=(
    sf-core
    sf-unified
    sf-health
    sf-memory
    sf-web
    smartfriend-unified
    smartfriend-api
    smartfriend-smartcore
    smartfriend-hybrid
  )

  for u in "${CORE_UNITS[@]}"; do
    if systemctl list-unit-files "$u" --no-legend &>/dev/null; then
      start_unit_safe "$u"
    fi
  done
}

start_suite_all() {
  log "=== [5] تشغيل بقية وحدات السيويت (sf-* / smartfriend-*) بدون لمس ffactory ==="
  if ((${#ALL_SUITE_UNITS[@]} == 0)); then
    warn "لا يوجد وحدات sf-* أو smartfriend-* مضافة في النظام."
    return
  fi

  for u in "${ALL_SUITE_UNITS[@]}"; do
    # وحدات الـ core تم التعامل معها في الخطوة السابقة – هنا نعيد تشغيلها لن يضر، لكن للتقليل:
    # نتخطى إن كانت ضمن CORE_UNITS بتشييك بسيط
    case "$u" in
      sf-core|sf-unified|sf-health|sf-memory|sf-web|smartfriend-unified|smartfriend-api|smartfriend-smartcore|smartfriend-hybrid)
        continue
        ;;
    esac
    start_unit_safe "$u"
  done
}

snapshot_status() {
  log "=== [6] لقطة حالة سريعة لوحدات السيويت بعد التشغيل ==="
  echo
  echo "---- sf-*.service (الآن) ----"
  systemctl list-units 'sf-*.service' --all --no-pager
  echo
  echo "---- smartfriend-*.service (الآن) ----"
  systemctl list-units 'smartfriend-*.service' --all --no-pager
  echo
  success "اكتمل توحيد DB وتشغيل خدمات السيويت (بدون لمس ffactory)."
}

main() {
  ensure_root
  log "=== SmartFriend Suite – توحيد DB + تشغيل كل خدمات السيويت (بدون symlink، بدون لمس ffactory) ==="
  check_canon_db
  fix_legacy_db_paths
  list_suite_units
  start_suite_core
  start_suite_all
  snapshot_status
}

main "$@"
