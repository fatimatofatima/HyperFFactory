#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

log(){ echo "[SF-UNIFY] $*"; }

INCLUDE_CRITICAL="no"
if [[ "${1:-}" == "--include-critical" ]]; then
  INCLUDE_CRITICAL="yes"
  log "سيتم تضمين تجميد Gateways/APIs legacy (الوحدات الحرجة) في مرحلة Freeze."
else
  log "تجميد Legacy سيكون للوحدات غير الحرجة فقط (Learning/Harvest/Bots/Guard...)."
  log "لو حبيت تضمّن Gateways/APIs لاحقًا شغّل:"
  log "  bash /root/sf_suite_unify_all.sh --include-critical"
fi

GEN_DOC="/root/sf_suite_generate_target_doc.sh"
PROMOTE="/root/sf_suite_promote_suite.sh"
FREEZE="/root/sf_suite_freeze_legacy.sh"
NGX="/root/sf_suite_nginx_switch_to_suite.sh"

# =========================================================
# 1) ضمان وجود سكربت هدف المعمارية (Step 2 – Doc)
# =========================================================
if [[ ! -x "$GEN_DOC" ]]; then
  log "إنشاء سكربت توليد وثيقة الهدف: $GEN_DOC"
  cat > "$GEN_DOC" <<'SCRIPT_GEN_DOC'
#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

DOC_DIR="/opt/smartfriend-suite/docs"
DOC_FILE="${DOC_DIR}/sf_suite_target_architecture.md"

mkdir -p "$DOC_DIR"

ts="$(date '+%F %T')"

cat > "$DOC_FILE" <<'DOC'
# SmartFriend Suite – Target Unified Architecture

> هذا الملف يحدد الهدف النهائي: أن تصبح SmartFriend Suite هي المنصة الرسمية الوحيدة
> لكل APIs, Brain, Memory, Bots, Spider, Web UI، بدون أي اعتماد تشغيل على smartfrind-*،
> مع الحفاظ على ffactory كما هو (بدون تعديل داخلي).

## 1. الهوية الرسمية (Brand)

- المنتج الرسمي: **SmartFriend Suite** (prefix: `sf-*` و `smartfriend-*` فقط).
- كل وحدات `smartfrind-*` تُعامل كـ Legacy:
  - يتم تجميدها (Freeze) وتشغيلها فقط عند الحاجة للتشخيص.

## 2. قواعد البيانات الرسمية

- قاعدة البيانات الموحدة:
  - `/opt/smartfriend-suite/var/db/smartfriend_unified.db`
- أي مسارات قديمة أصبحت مرتبطة بهذه القاعدة (hardlinks) ولا يوجد نسخ متعدّدة.

## 3. كتالوج الخدمات الرسمية (Target Service Catalog)

### 3.1. APIs / Gateways الرسمية

- Gateway Ask (واجهة الاستفسار الرئيسية):
  - وحدة رسمية: `sf-unified.service` أو وحدة جديدة مخصصة (مثلاً: `sf-gateway.service`).
  - الهدف: استقبال كل طلبات /ask/ و /api/ من nginx بدل `smartfrind-gateway.service`.

- Unified API:
  - وحدة رسمية: `sf-unified.service`
  - دورها:
    - توحيد الوصول لـ:
      - Memory
      - Brain / Learning
      - Knowledge
      - Integrations

- Core / Internal API:
  - وحدة رسمية مقترحة: `smartfriend-core.service` (إن وجدت) أو `sf-core.service`.
  - تستخدم داخليًا فقط من باقي مكونات السيوت.

- Memory API:
  - وحدة رسمية: `sf-memory.service`
  - endpoint ثابت (مثلاً 8214) لتوجيه `/memory/` من nginx.

- Web UI:
  - وحدة رسمية: `sf-web.service`
  - Dashboard رسمي للسيوت على بورت ثابت (مثلاً 8390)، من nginx على `/suite/` أو `/dashboard/` لاحقًا.

### 3.2. Brain / Learning / Ingest

- المنظومة الرسمية (sf-*):
  - `sf-ingest.service`
  - `sf-kb-build.service`
  - `sf-fts-maint.service`
  - `sf-learn.service`
  - `sf-learning.service`
  - Timers:
    - `sf-kb-build.timer`
    - `sf-fts-maint.timer`
    - `sf-learn.timer`

- المنظومة القديمة (smartfrind-*):
  - `smartfrind-harvest.service`
  - `smartfrind-ingest.service`
  - `smartfrind-raw-clean.service`
  - `smartfrind-autolearn.service`
  - `smartfrind-learning.service`
  - `smartfrind-learning-agent.service`
  - `smartfrind-trainer.service`
  - `smartfrind-cma-sync.service`
  - `smartfrind-reflector.service`
  - يتم تجميدها في Step 3 بعد نقل أفضل المنطق للكود الجديد.

### 3.3. Spider / Harvester

- Spider الرسمي:
  - `sf-spider.service` + `sf-spider.timer`

- Legacy:
  - `smartfrind-harvest.service`
  - `smartfrind-ingest.service`
  - `smartfrind-raw-clean.service`
  - + timers المرتبطة

### 3.4. Bots الرسمية

- Main Client Bot:
  - `sf-telegram.service` أو `sf-smartfriend.service`
- Programmer / Dev Bot:
  - `sf-bot-programmer.service` أو `sf-bot-dev.service`
- Audit / Logs Bot:
  - `sf-telegram-audit.service` أو `sf-audit-bot.service`
- SmartFactory Bot:
  - `sf-smartfactory.service`

Legacy Bots:
  - `smartfrind-bot.service`
  - `smartfrind-learner.service`

### 3.5. Health / Guard

- Health/Guard الرسمي:
  - `sf-health.service`
  - `sf-smoke.service` + `sf-smoke.timer`

- Legacy:
  - `smartfrind-core-watchdog.service` + timer
  - `smartfrind-watchdog.service` + timer
  - `smartfrind-guard.service` + timer
  - `smartfrind-envwatch.service` + timer

## 4. Nginx – توحيد المسارات

- الملف: `/etc/nginx/sites-enabled/smartfriend.conf`

الهدف النهائي:
- `/`          → Redirect واجهة (ffactory/docs أو Web UI لاحقاً).
- `/ffactory/` → كما هي الآن (لا لمس ffactory داخليًا).
- `/unified/`  → Unified API الرسمي (sf-unified).
- `/core/`     → Core API الرسمي (من sf-*).
- `/memory/`   → Memory API الرسمي (sf-memory).
- مستقبلاً: `/suite/` أو `/dashboard/` → sf-web.

## 5. الفجوات G1..G10 وربطها

- G1: Brand → اعتماد sf-* فقط للإنتاج.
- G2: Ports → نقل البورتات 8210/8211/8220/8214/8390 لـ sf-*.
- G3: Memory → تشغيل `sf-memory` خلف `/memory/`.
- G4: Web UI → تشغيل `sf-web` وربطه من nginx.
- G5: Brain → اعتماد `sf-*` Brain وإيقاف legacy.
- G6: Spider → `sf-spider` رسميًا.
- G7: Bots → كتالوج Bots رسمي تحت `sf-*`.
- G8: Health → `sf-health` رسميًا بدل watchdogs القديمة.
- G9: ENV → ملف مركزي مثل `/etc/smartfriend/sf_suite.env`.
- G10: Legacy Units → أرشفة وحدات `smartfrind-*` في `/opt/smartfriend-suite/legacy_units/`.

## 6. مبادئ تنفيذية

- لا حذف لقواعد البيانات أو بيانات legacy.
- smartfrind-* يتم:
  - stop + disable
  - نقل ملفات وحدات systemd لأرشيف
- ffactory يبقى كما هو:
  - لا تعديل على `/opt/ffactory`
  - لا تعديل على `stack/nginx.gateway.conf`

DOC

echo "[SF-DOC] تم إنشاء / تحديث ملف الهدف:"
echo "  $DOC_FILE"
echo "[SF-DOC] Timestamp: $ts"
SCRIPT_GEN_DOC
  chmod +x "$GEN_DOC"
else
  log "سكربت الهدف موجود بالفعل: $GEN_DOC"
fi

# =========================================================
# 2) ضمان وجود سكربت Promote للسيوت
# =========================================================
if [[ ! -x "$PROMOTE" ]]; then
  log "إنشاء سكربت Promote السيوت: $PROMOTE"
  cat > "$PROMOTE" <<'SCRIPT_PROMOTE'
#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

log(){ echo "[SF-PROMOTE] $*"; }

ENV_DIR="/etc/smartfriend"
ENV_FILE="${ENV_DIR}/sf_suite.env"

mkdir -p "$ENV_DIR"

if [[ ! -f "$ENV_FILE" ]]; then
  log "إنشاء ملف البيئة الأساسي: $ENV_FILE"
  cat > "$ENV_FILE" <<'ENV'
# SmartFriend Suite – Unified ENV
SF_DB_PATH="/opt/smartfriend-suite/var/db/smartfriend_unified.db"
SF_KNOWLEDGE_DIR="/opt/smartfriend-suite/var/knowledge"
SF_LOG_DIR="/opt/smartfriend-suite/var/log"

# يمكن إضافة TELEGRAM TOKENS هنا:
# SF_MAIN_BOT_TOKEN="xxxx"
# SF_AUDIT_BOT_TOKEN="xxxx"
# SF_SMARTFACTORY_BOT_TOKEN="xxxx"

# SF_MEMORY_BACKEND="sqlite"
# SF_MEMORY_DB="/opt/smartfriend-suite/var/db/smartfriend_memory.db"
ENV
else
  log "ملف البيئة موجود مسبقًا: $ENV_FILE"
fi

CORE_SERVICES=(
  sf-unified.service
  sf-memory.service
  sf-web.service
  sf-learn.service
  sf-learning.service
  sf-ingest.service
  sf-kb-build.service
  sf-fts-maint.service
  sf-health.service
  sf-spider.service
)

BOT_SERVICES=(
  sf-telegram.service
  sf-telegram-audit.service
  sf-smartfriend.service
  sf-smartfrind.service
  sf-smartfactory.service
  sf-bot-assistant.service
  sf-bot-dev.service
  sf-bot-model.service
)

log "إعادة تحميل systemd..."
systemctl daemon-reload

promote_group() {
  local group_name="$1"; shift
  local services=("$@")
  log "تفعيل وتشغيل مجموعة: $group_name"
  for unit in "${services[@]}"; do
    if systemctl list-unit-files "$unit" &>/dev/null; then
      log "تمكين $unit"
      systemctl enable "$unit" || log "تحذير: فشل enable لـ $unit"
      log "إعادة تشغيل $unit"
      systemctl restart "$unit" || log "تحذير: فشل restart لـ $unit"
      systemctl --no-pager --plain status "$unit" | sed -n '1,5p' || true
      echo
    else
      log "وحدة غير موجودة (تجاوز): $unit"
    fi
  done
}

promote_group "Core/Brain/Memory/Web/Spider/Health" "${CORE_SERVICES[@]}"
promote_group "Bots" "${BOT_SERVICES[@]}"

log "انتهى Promote للسيوت. لم يتم لمس smartfrind-*."
SCRIPT_PROMOTE
  chmod +x "$PROMOTE"
else
  log "سكربت Promote موجود بالفعل: $PROMOTE"
fi

# =========================================================
# 3) ضمان وجود سكربت Freeze للـ Legacy
# =========================================================
if [[ ! -x "$FREEZE" ]]; then
  log "إنشاء سكربت Freeze للـ Legacy: $FREEZE"
  cat > "$FREEZE" <<'SCRIPT_FREEZE'
#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

log(){ echo "[SF-FREEZE] $*"; }

ARCHIVE_DIR="/opt/smartfriend-suite/legacy_units"
mkdir -p "$ARCHIVE_DIR"

LEGACY_SAFE_UNITS=(
  smartfrind-harvest.service
  smartfrind-ingest.service
  smartfrind-raw-clean.service
  smartfrind-autolearn.service
  smartfrind-learning.service
  smartfrind-learning-agent.service
  smartfrind-trainer.service
  smartfrind-cma-sync.service
  smartfrind-reflector.service
  smartfrind-learner.service
  smartfrind-core-watchdog.service
  smartfrind-watchdog.service
  smartfrind-guard.service
  smartfrind-monitor.service
  smartfrind-envwatch.service
  smartfrind-backup.service
  smartfrind-bot.service
  smartfrind-runner.service
)

LEGACY_SAFE_TIMERS=(
  smartfrind-autolearn.timer
  smartfrind-backup.timer
  smartfrind-cma-sync.timer
  smartfrind-core-watchdog.timer
  smartfrind-envwatch.timer
  smartfrind-guard.timer
  smartfrind-harvest.timer
  smartfrind-ingest.timer
  smartfrind-learner.timer
  smartfrind-learning-agent.timer
  smartfrind-raw-clean.timer
  smartfrind-reflector.timer
  smartfrind-watchdog.timer
)

LEGACY_MISC_UNITS=(
  smartfrind-delta.sh.service
  smartfrind-setup.sh.service
  smartfrind-simple.service
  smartfrind-ultra.service
  smartfrind-advanced.service
  smartfrind-final.service
  smartfrind-qa.service
  smartfrind-envwatch.service
)

LEGACY_CRITICAL_UNITS=(
  smartfrind-gateway.service
  smartfrind-ai-gateway.service
  smartfrind-local.service
  smartfrind-api.service
  smartfrind-core.service
  smartfrind-unified.service
)

freeze_unit() {
  local unit="$1"
  if ! systemctl list-unit-files "$unit" &>/dev/null; then
    log "وحدة غير موجودة (تجاوز): $unit"
    return 0
  fi

  log "إيقاف $unit..."
  systemctl stop "$unit" 2>/dev/null || true

  log "تعطيل $unit..."
  systemctl disable "$unit" 2>/dev/null || true

  local unit_file="/etc/systemd/system/${unit}"
  if [[ -f "$unit_file" ]]; then
    log "أرشفة ملف الوحدة: $unit_file → $ARCHIVE_DIR"
    mv "$unit_file" "$ARCHIVE_DIR/" || log "تحذير: فشل نقل $unit_file"
  else
    log "لا يوجد ملف وحدة في /etc/systemd/system لـ $unit"
  fi
}

log "إعادة تحميل systemd..."
systemctl daemon-reload

log "تجميد وحدات Legacy الآمنة..."
for u in "${LEGACY_SAFE_UNITS[@]}"; do
  freeze_unit "$u"
done

log "تجميد Timers القديمة..."
for u in "${LEGACY_SAFE_TIMERS[@]}"; do
  freeze_unit "$u"
done

log "تجميد وحدات Legacy الإضافية..."
for u in "${LEGACY_MISC_UNITS[@]}"; do
  freeze_unit "$u"
done

INCLUDE_CRITICAL="no"
if [[ "${1:-}" == "--include-critical" ]]; then
  INCLUDE_CRITICAL="yes"
fi

if [[ "$INCLUDE_CRITICAL" == "yes" ]]; then
  log "تجميد الوحدات الحرجة (Gateways/APIs). تأكد أن السيوت ماسكة الدور."
  for u in "${LEGACY_CRITICAL_UNITS[@]}"; do
    freeze_unit "$u"
  done
else
  log "تم تجاهل الوحدات الحرجة. لتجميدها لاحقًا:"
  log "  bash /root/sf_suite_freeze_legacy.sh --include-critical"
fi

log "إعادة تحميل systemd بعد التغييرات..."
systemctl daemon-reload

log "انتهى Freeze للـ Legacy. لا يوجد حذف لأي DB."
SCRIPT_FREEZE
  chmod +x "$FREEZE"
else
  log "سكربت Freeze موجود بالفعل: $FREEZE"
fi

# =========================================================
# 4) ضمان وجود سكربت Nginx Switch
# =========================================================
if [[ ! -x "$NGX" ]]; then
  log "إنشاء سكربت Nginx switch: $NGX"
  cat > "$NGX" <<'SCRIPT_NGX'
#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

log(){ echo "[SF-NGINX] $*"; }

CONF_FILE="/etc/nginx/sites-enabled/smartfriend.conf"

UNIFIED_BACKEND="http://127.0.0.1:8220/"
CORE_BACKEND="http://127.0.0.1:8211/"
MEMORY_BACKEND="http://127.0.0.1:8214/"
ROOT_REDIRECT="/ffactory/docs"

log "كتابة smartfriend.conf جديد إلى: $CONF_FILE"

cat > "$CONF_FILE" <<NGINX
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name 62.171.172.105 _;

    client_max_body_size 32m;

    location /nginx-health {
        access_log off;
        return 200 'OK';
        add_header Content-Type text/plain;
    }

    location = / {
        return 302 ${ROOT_REDIRECT};
    }

    location = /ffactory/ {
        return 302 /ffactory/docs;
    }

    location /ffactory/ {
        proxy_pass         ${UNIFIED_BACKEND};
        proxy_http_version 1.1;
        proxy_set_header   Host               \$host;
        proxy_set_header   X-Real-IP          \$remote_addr;
        proxy_set_header   X-Forwarded-For    \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto  \$scheme;
    }

    location /core/ {
        proxy_pass         ${CORE_BACKEND};
        proxy_http_version 1.1;
        proxy_set_header   Host               \$host;
        proxy_set_header   X-Real-IP          \$remote_addr;
        proxy_set_header   X-Forwarded-For    \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto  \$scheme;
    }

    location /unified/ {
        proxy_pass         ${UNIFIED_BACKEND};
        proxy_http_version 1.1;
        proxy_set_header   Host               \$host;
        proxy_set_header   X-Real-IP          \$remote_addr;
        proxy_set_header   X-Forwarded-For    \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto  \$scheme;
    }

    location /memory/ {
        proxy_pass         ${MEMORY_BACKEND};
        proxy_http_version 1.1;
        proxy_set_header   Host               \$host;
        proxy_set_header   X-Real-IP          \$remote_addr;
        proxy_set_header   X-Forwarded-For    \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto  \$scheme;
    }
}
NGINX

log "اختبار إعدادات nginx..."
nginx -t

log "إعادة تحميل nginx..."
systemctl reload nginx

log "انتهى تحديث smartfriend.conf."
SCRIPT_NGX
  chmod +x "$NGX"
else
  log "سكربت Nginx موجود بالفعل: $NGX"
fi

# =========================================================
# 5) التنفيذ بالترتيب
# =========================================================
log "تشغيل Step 2 – توليد وثيقة الهدف..."
bash "$GEN_DOC"

log "تشغيل Promote للسيوت..."
bash "$PROMOTE"

log "تشغيل Freeze للـ Legacy (بدون الوحدات الحرجة هنا)..."
bash "$FREEZE"

log "تشغيل Switch لـ Nginx..."
bash "$NGX"

if [[ "$INCLUDE_CRITICAL" == "yes" ]]; then
  log "تشغيل Freeze إضافي للوحدات الحرجة (Gateways/APIs)..."
  bash "$FREEZE" --include-critical
fi

log "اكتمل سكربت التوحيد SF Suite Unify All."
