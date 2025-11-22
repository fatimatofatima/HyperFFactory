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
- أي مسارات قديمة (في smartfrind أو ffactory) أصبحت مرتبطة بهذه القاعدة (hardlinks) ولا يوجد نسخ متعدّدة.

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
      - Integrations (Telegram, ffactory integration لو موجودة)

- Core / Internal API:
  - وحدة رسمية مقترحة: `smartfriend-core.service` (إن وجدت) أو `sf-core.service` (في حال موجودة).
  - تستخدم داخليًا فقط من باقي مكونات السيوت.

- Memory API:
  - وحدة رسمية: `sf-memory.service`
  - يجب أن توفّر endpoint ثابت (مثلاً على 8214) يتم توجيه `/memory/` عليه من nginx.

- Web UI:
  - وحدة رسمية: `sf-web.service`
  - الهدف:
    - تقديم Dashboard رسمي للسيوت على بورت ثابت (مثلاً 8390).
    - الوصول له من nginx على مسار مثل `/suite/` أو `/dashboard/`.

### 3.2. Brain / Learning / Ingest

- المنظومة الرسمية: وحدات `sf-*` التالية:
  - `sf-ingest.service`
  - `sf-kb-build.service`
  - `sf-fts-maint.service`
  - `sf-learn.service`
  - `sf-learning.service`
  - + Timers:
    - `sf-kb-build.timer`
    - `sf-fts-maint.timer`
    - `sf-learn.timer`

- المنظومة القديمة:
  - كل وحدات:
    - `smartfrind-harvest.service`
    - `smartfrind-ingest.service`
    - `smartfrind-raw-clean.service`
    - `smartfrind-autolearn.service`
    - `smartfrind-learning.service`
    - `smartfrind-learning-agent.service`
    - `smartfrind-trainer.service`
    - وكل الـ timers التابعة.
  - يتم تجميدها في Step 3 (Freeze Legacy) بعد نقل أفضل المنطق منها للسيوت (كودياً).

### 3.3. Spider / Harvester

- Spider الرسمي:
  - `sf-spider.service` + `sf-spider.timer`
  - مسؤول عن:
    - Web crawling
    - Harvesting
    - تغذية الـ Ingest الرسمي في السيوت

- Spider/Harvester legacy:
  - `smartfrind-harvest.service`
  - `smartfrind-ingest.service`
  - `smartfrind-raw-clean.service`
  - + timers المرتبطة
  - يتم تجميدها بعد اعتماد Spider الرسمي.

### 3.4. Bots الرسمية

- Main Client Bot:
  - `sf-telegram.service` (أو `sf-smartfriend.service` حسب قرارك النهائي)
- Programmer / Dev Bot:
  - `sf-bot-programmer.service` (إن وُجد) أو `sf-bot-dev.service`
- Audit / Logs Bot:
  - `sf-telegram-audit.service` أو `sf-audit-bot.service`
- SmartFactory Bot:
  - `sf-smartfactory.service`

- Legacy Bots:
  - `smartfrind-bot.service`
  - `smartfrind-learner.service`
  - يتم تجميدها في Step 3.

### 3.5. Health / Guard / Watchdogs

- Health/Guard الرسمي:
  - `sf-health.service`
  - `sf-smoke.service` + `sf-smoke.timer`
- Legacy health/guard:
  - `smartfrind-core-watchdog.service` + timer
  - `smartfrind-watchdog.service` + timer
  - `smartfrind-guard.service` + timer
  - `smartfrind-envwatch.service` + timer
  - يتم تجميدها تدريجيًا بعد نجاح health الرسمي.

## 4. Nginx – توحيد المسارات

- الملف الرسمي:
  - `/etc/nginx/sites-enabled/smartfriend.conf`

- الهدف النهائي:
  - `/`            → توجيه إلى Web UI الرسمي للسيوت أو ffactory حسب الحاجة.
  - `/ffactory/`   → تركها كما هي من حيث الباك إند، بدون لمس ffactory داخليًا.
  - `/unified/`    → endpoint السيوت الرسمي (sf-unified).
  - `/core/`       → Core API الرسمي (من sf-*).
  - `/memory/`     → Memory API الرسمي (sf-memory).
  - مسارات إضافية مستقبلية:
    - `/suite/` أو `/dashboard/` → sf-web.

## 5. الفجوات G1..G10 وربطها بالخطة

- G1 (Brand): إنهاء الاعتماد على `smartfrind-*` كخدمات Production، واعتماد `sf-*` فقط.
- G2 (Ports): نقل ملكية البورتات الأساسية (8210, 8211, 8220, 8214, 8390) تدريجيًا إلى sf-* (أو فصلها تمامًا عن legacy).
- G3 (Memory): تشغيل `sf-memory` خلف `/memory/` بشكل رسمي.
- G4 (Web UI): تشغيل `sf-web` على بورت ثابت وربط nginx به.
- G5 (Brain): اعتماد `sf-*` Brain وإيقاف منظومة التعلم legacy.
- G6 (Spider): تشغيل `sf-spider` كـ Spider رسمي وإيقاف `smartfrind-harvest/ingest`.
- G7 (Bots): توثيق كتالوج bots الرسمي تحت `sf-*` فقط.
- G8 (Health): اعتماد `sf-health` كـ Health/Guard رسمي وإلغاء اعتماد watchdogs القديمة.
- G9 (ENV): استخدام ملف إعداد مركزي للسيوت (مثلاً `/etc/smartfriend/sf_suite.env`).
- G10 (Legacy Units): أرشفة وحدات `smartfrind-*` في مجلد مثل `/opt/smartfriend-suite/legacy_units/` بعد تجميدها.

## 6. ملاحظات تنفيذية

- لا يتم حذف أي قاعدة بيانات أو ملفات legacy.
- كل وحدات smartfrind-* يتم:
  - إيقافها
  - Disable
  - نقل ملفات الـ unit إلى مجلد أرشيف
- ffactory تبقى كما هي:
  - لا تعديل على `/opt/ffactory`
  - لا تعديل على `stack/nginx.gateway.conf`

DOC

echo "[SF-DOC] تم إنشاء / تحديث ملف الهدف:"
echo "  $DOC_FILE"
echo "[SF-DOC] Timestamp: $ts"
