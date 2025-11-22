#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

log(){ echo "[$(date '+%F %T')] $*"; }
warn(){ echo "WARN: $*" >&2; }

ROOT="/opt/smartfriend-suite/smartfriend"

if [ ! -d "$ROOT" ]; then
  warn "ROOT $ROOT غير موجود – لا شيء سيتم تعديله."
  exit 0
fi

# اكتشاف المستخدم الذي تعمل تحته خدمات smartfrind
APP_USER=$(systemctl show -p User --value smartfrind-simple.service 2>/dev/null || true)
APP_USER=${APP_USER:-smartfrind}

log "استخدام المستخدم: ${APP_USER}"

# 1) ضمان مجلد logs موجود
if [ ! -d "$ROOT/logs" ]; then
  log "إنشاء $ROOT/logs"
  mkdir -p "$ROOT/logs"
fi

chown -R "${APP_USER}:${APP_USER}" "$ROOT/logs" || true

# 2) إصلاح صلاحيات venv/bin/python لو موجود
if [ -x "$ROOT/venv/bin/python" ]; then
  log "تثبيت صلاحيات التنفيذ على $ROOT/venv/bin/python"
  chmod 750 "$ROOT/venv/bin/python" || true
  chown "${APP_USER}:${APP_USER}" "$ROOT/venv/bin/python" || true
elif [ -f "$ROOT/venv/bin/python" ]; then
  log "جعل $ROOT/venv/bin/python قابلاً للتنفيذ"
  chmod 750 "$ROOT/venv/bin/python" || true
  chown "${APP_USER}:${APP_USER}" "$ROOT/venv/bin/python" || true
else
  warn "لم يتم العثور على $ROOT/venv/bin/python – لن يتم لمس الـ venv."
fi

# 3) تهدئة smartfrind-monitor (خطأ WorkingDirectory في قسم Install)
UNIT_MON="/etc/systemd/system/smartfrind-monitor.service"
if [ -f "$UNIT_MON" ]; then
  if grep -q '^WorkingDirectory=' "$UNIT_MON"; then
    log "تعطيل WorkingDirectory الخاطئ في smartfrind-monitor.service (قسم Install)"
    sed -i 's/^WorkingDirectory=/#WorkingDirectory=/' "$UNIT_MON"
  fi
fi

# 4) إيقاف الخدمات المتصادمة على المنفذ 8210 أو غير الجاهزة (نبقي simple فقط كبوابة مؤقتة)
BROKEN_UNITS=(
  smartfrind-ultra.service
  smartfrind-unified.service
  smartfrind-local.service
  smartfrind-qa.service
)

for u in "${BROKEN_UNITS[@]}"; do
  if systemctl list-unit-files | grep -q "^${u}"; then
    log "تعطيل الخدمة غير المستقرة: $u"
    systemctl disable --now "$u" 2>/dev/null || true
  fi
done

# 5) إصلاح مشكلة smartfrind-reflector (إنشاء قاعدة البيانات والمسار)
DB_PY="$ROOT/app/smartfrind/db.py"
if [ -f "$DB_PY" ]; then
  log "محاولة استخراج مسار قاعدة البيانات من $DB_PY"
  DB_PATH=$(python3 - <<'PY' 2>/dev/null || true)
import re, pathlib, sys
p = pathlib.Path("/opt/smartfriend-suite/smartfriend/app/smartfrind/db.py")
try:
    text = p.read_text(encoding="utf-8")
except Exception:
    sys.exit(0)
m = re.search(r'DB\s*=\s*[\'"]([^\'"]+)[\'"]', text)
if m:
    print(m.group(1))
PY
  if [ -n "${DB_PATH:-}" ]; then
    log "مسار قاعدة البيانات حسب الكود: $DB_PATH"
    DB_DIR=$(dirname "$DB_PATH")
    mkdir -p "$DB_DIR"
    if [ ! -f "$DB_PATH" ]; then
      log "إنشاء ملف قاعدة البيانات الفارغ (سيملأه التطبيق لاحقاً)"
      : > "$DB_PATH"
    fi
    chown -R "${APP_USER}:${APP_USER}" "$DB_DIR" || true
  else
    warn "تعذر استخراج DB من db.py – لن يتم تعديل قواعد البيانات."
  fi
else
  warn "لم يتم العثور على $DB_PY – تخطي خطوة reflector DB."
fi

# 6) إعادة تحميل systemd وإعادة تشغيل الخدمات الأساسية للسويت
log "إعادة تحميل تعريفات systemd"
systemctl daemon-reload

CORE_UNITS=(
  smartfrind-monitor.service
  smartfrind-simple.service
  smartfrind-reflector.service
)

for u in "${CORE_UNITS[@]}"; do
  if systemctl list-unit-files | grep -q "^${u}"; then
    log "إعادة تشغيل $u"
    systemctl restart "$u" 2>/dev/null || true
    systemctl status "$u" --no-pager -l || true
  fi
done

log "انتهى sf_suite_hotfix_20251115 – بدون أي لمس لـ ffactory."
