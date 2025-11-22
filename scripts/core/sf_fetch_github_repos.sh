#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

BASE="/opt/github_cache"
mkdir -p "$BASE"

log(){ echo "[$(date '+%F %T')] $*"; }

log "=== Fetch SmartFriend GitHub Repos ==="
log "BASE = $BASE"
log

# الاسم + الرابط
repos=(
  "smartfrind https://github.com/fatimatofatima/smartfrind.git"
  "smartfriend-suite https://github.com/fatimatofatima/smartfriend-suite.git"
  "smartfriend-complete-system https://github.com/fatimatofatima/smartfriend-complete-system.git"
)

for r in "${repos[@]}"; do
  name="${r%% *}"
  url="${r#* }"
  dir="$BASE/$name"

  log "------------------------------------------------------------"
  log ">> Repo: $name"
  log "   URL : $url"
  log "   DIR : $dir"

  if [[ -d "$dir/.git" ]]; then
    log "   [*] موجود مسبقاً – تحديث من GitHub..."
    git -C "$dir" remote set-url origin "$url" || true
    git -C "$dir" fetch --all --prune
    # نحاول main ثم master
    if git -C "$dir" rev-parse --verify origin/main >/dev/null 2>&1; then
      git -C "$dir" reset --hard origin/main
    else
      git -C "$dir" reset --hard origin/master || true
    fi
  else
    log "   [+] أول مرة – clone من GitHub..."
    git clone "$url" "$dir"
  fi

  head_sha="$(git -C "$dir" rev-parse --short HEAD 2>/dev/null || echo '?')"
  log "   HEAD: $head_sha"
done

log
log "=== مقارنة سريعة مع المسارات الحية على السيرفر ==="

# smartfriend-suite: المصدر الرسمي للسويت تحت /opt/smartfriend-suite
if [[ -d /opt/smartfriend-suite ]]; then
  log ">>> مقارنة smartfriend-suite:"
  log "    /opt/github_cache/smartfriend-suite  <->  /opt/smartfriend-suite"
  diff -qr /opt/github_cache/smartfriend-suite /opt/smartfriend-suite | head -n 50 || true
else
  log "[WARN] /opt/smartfriend-suite غير موجود على السيرفر."
fi

# smartfrind: لو موجود مسار مستقل
if [[ -d /opt/smartfrind ]]; then
  log
  log ">>> مقارنة smartfrind:"
  log "    /opt/github_cache/smartfrind  <->  /opt/smartfrind"
  diff -qr /opt/github_cache/smartfrind /opt/smartfrind | head -n 50 || true
else
  log "[INFO] /opt/smartfrind غير موجود – هنستخدمه لاحقاً لو حابب نفصل الكور legacy."
fi

log
log "=== ملاحظة تشغيلية ==="
log "[*] هذه العملية لا تغيّر أي ملفات تحت /opt/smartfriend-suite أو ffactory."
log "[*] الهدف فقط إحياء الكود من GitHub وإظهار الفروقات على الشاشة."
