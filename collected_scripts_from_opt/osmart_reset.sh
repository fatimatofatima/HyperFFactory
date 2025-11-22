#!/usr/bin/env bash
set -euo pipefail

# ===== إعدادات قابلة للتعديل =====
PG_VER="${PG_VER:-16}"
DB_NAME="${DB_NAME:-osmart}"
SUPER_USER="${SUPER_USER:-root}"
SUPER_PASS="${SUPER_PASS:-Aa100200@@}"
APP_USER="${APP_USER:-osmart_app}"
APP_PASS="${APP_PASS:-Aa100200@@}"

PG_ETC="/etc/postgresql/${PG_VER}/main"
CONF_D="${PG_ETC}/conf.d"
PG_HBA="${PG_ETC}/pg_hba.conf"

log(){ echo "[*] $*"; }
pkg(){ dpkg -s "$1" &>/dev/null; }

need_install() {
  local miss=()
  for p in "$@"; do pkg "$p" || miss+=("$p"); done
  if ((${#miss[@]})); then
    apt-get update -y
    DEBIAN_FRONTEND=noninteractive apt-get install -y "${miss[@]}"
  fi
}

# 0) متطلبات ونُصُب Postgres 16
log "تحضير المتطلبات…"
need_install curl ca-certificates gnupg lsb-release
install -d -m 0755 /etc/apt/keyrings
if [ ! -f /etc/apt/keyrings/pgdg.gpg ]; then
  curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
    | gpg --dearmor -o /etc/apt/keyrings/pgdg.gpg
fi
echo "deb [signed-by=/etc/apt/keyrings/pgdg.gpg] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" \
  > /etc/apt/sources.list.d/pgdg.list
apt-get update -y
need_install "postgresql-${PG_VER}" "postgresql-client-${PG_VER}"
systemctl enable --now postgresql

# 1) TimescaleDB (اختياري لكن هنفعّله طالما متاح)
log "تثبيت TimescaleDB…"
if [ ! -f /etc/apt/sources.list.d/timescaledb.list ]; then
  curl -fsSL https://packagecloud.io/timescale/timescaledb/gpgkey \
    | gpg --dearmor -o /usr/share/keyrings/timescaledb.gpg
  echo "deb [signed-by=/usr/share/keyrings/timescaledb.gpg] https://packagecloud.io/timescale/timescaledb/ubuntu/ $(lsb_release -cs) main" \
    > /etc/apt/sources.list.d/timescaledb.list
  apt-get update -y
fi
need_install timescaledb-2-postgresql-${PG_VER} || true

# 2) ضبط التحميل المُسبق لِـ TimescaleDB
log "تفعيل shared_preload_libraries=timescaledb…"
install -d -m 0755 "${CONF_D}"
echo "shared_preload_libraries = 'timescaledb'" > "${CONF_D}/99-timescaledb.conf"
systemctl restart postgresql

# 3) أمان الاتصال المحلي (SCRAM + localhost)
log "تهيئة pg_hba.conf للمصادقة SCRAM على localhost…"
cp -an "${PG_HBA}" "${PG_HBA}.bak" || true
grep -q "127\.0\.0\.1/32.*scram-sha-256" "${PG_HBA}" || \
  echo "host  all  all  127.0.0.1/32  scram-sha-256" >> "${PG_HBA}"
grep -q "::1/128.*scram-sha-256" "${PG_HBA}" || \
  echo "host  all  all  ::1/128       scram-sha-256" >> "${PG_HBA}"
systemctl reload postgresql

# 4) المستخدمين وكلمات المرور
log "إنشاء/تحديث المستخدمين root و ${APP_USER}…"
sudo -u postgres psql -v ON_ERROR_STOP=1 <<SQL
ALTER SYSTEM SET password_encryption = 'scram-sha-256';
SELECT pg_reload_conf();

DO \$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='${SUPER_USER}') THEN
    EXECUTE 'CREATE ROLE ${SUPER_USER} LOGIN SUPERUSER PASSWORD ''${SUPER_PASS}''';
  ELSE
    EXECUTE 'ALTER ROLE ${SUPER_USER} WITH LOGIN SUPERUSER PASSWORD ''${SUPER_PASS}''';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='${APP_USER}') THEN
    EXECUTE 'CREATE ROLE ${APP_USER} LOGIN PASSWORD ''${APP_PASS}''';
  ELSE
    EXECUTE 'ALTER ROLE ${APP_USER} WITH LOGIN PASSWORD ''${APP_PASS}''';
  END IF;
END
\$\$;
SQL

# 5) إسقاط وبناء قاعدة البيانات من الصفر
log "إعادة إنشاء قاعدة ${DB_NAME}…"
sudo -u postgres psql -v ON_ERROR_STOP=1 <<SQL
-- إنهاء أي اتصالات نشطة
SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='${DB_NAME}' AND pid <> pg_backend_pid();

DROP DATABASE IF EXISTS "${DB_NAME}";
CREATE DATABASE "${DB_NAME}" OWNER "${SUPER_USER}" ENCODING 'UTF8' LC_COLLATE 'C' LC_CTYPE 'C' TEMPLATE template0;
ALTER DATABASE "${DB_NAME}" SET timezone TO 'UTC';
SQL

# 6) إنشاء المخطط المطلوب (بالترتيب اللي طلبته)
log "إنشاء الجداول…"
sudo -u postgres psql -v ON_ERROR_STOP=1 -d "${DB_NAME}" <<'SQL'
-- 1) جدول عدم التكرار
CREATE TABLE IF NOT EXISTS "عدم_التكرار" (
  "هاش"             TEXT PRIMARY KEY,
  "حجم"             BIGINT NOT NULL CHECK ("حجم" >= 0),
  "تاريخ_الالتقاط"  TIMESTAMPTZ
);

-- 2) جدول الحالة
CREATE TABLE IF NOT EXISTS "حالة_الفحص" (
  "هاش"     TEXT PRIMARY KEY
            REFERENCES "عدم_التكرار"("هاش") ON DELETE CASCADE,
  "الحالة"  TEXT NOT NULL CHECK ("الحالة" IN ('none','ok','rejec','path'))
);

-- 3) جدول أسماء العناصر
CREATE TABLE IF NOT EXISTS "اسماء_العناصر" (
  "id"              INT PRIMARY KEY,
  "الاسم_عربي"      TEXT NOT NULL,
  "الاسم_انجليزي"    TEXT NOT NULL,
  "وزن_الرهان"      INT  NOT NULL
);

-- 4) جدول النتائج اليومية
CREATE TABLE IF NOT EXISTS "النتائج_اليومية" (
  "هاش"             TEXT NOT NULL
                     REFERENCES "عدم_التكرار"("هاش") ON DELETE CASCADE,
  "تاريخ_الالتقاط"  TIMESTAMPTZ,
  "رقم_الجولة"      INT NOT NULL,
  "اسم_الأيقونة"    TEXT,
  "شريط_اقتصاص"     TEXT,
  "جملة_الشرط"      TEXT,
  "الصف_كامل"       JSONB,
  "نتيجة_الجولة"    TEXT
);

-- 5) دالة تبني جدول تدريب مخصص لكل عنصر: تدريب_العنصر_<id>
CREATE OR REPLACE FUNCTION create_training_table(p_item_id INT)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  EXECUTE format(
    'CREATE TABLE IF NOT EXISTS "تدريب_العنصر_%s" (
       "هاش"           TEXT NOT NULL
                        REFERENCES "عدم_التكرار"("هاش") ON DELETE CASCADE,
       "نوع_العملية"   TEXT NOT NULL,        -- تدوير/قلب/إضاءة/شفافية… إلخ
       "معلمات"        JSONB,                 -- باراميترز العملية
       "نقاط"          INT,                   -- نقاط/Score
       "ثقة"           DOUBLE PRECISION       -- نسبة الثقة
     )', p_item_id);
END $$;

-- (اختياري) تفعيل الإضافة لو متاحة
CREATE EXTENSION IF NOT EXISTS timescaledb;
SQL

# 7) الصلاحيات للتطبيق
log "منح صلاحيات للتطبيق…"
sudo -u postgres psql -v ON_ERROR_STOP=1 -d "${DB_NAME}" <<SQL
ALTER SCHEMA public OWNER TO "${SUPER_USER}";
GRANT USAGE ON SCHEMA public TO "${APP_USER}";
GRANT SELECT,INSERT,UPDATE,DELETE ON ALL TABLES IN SCHEMA public TO "${APP_USER}";
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT,INSERT,UPDATE,DELETE ON TABLES TO "${APP_USER}";
SQL

# 8) اختبار سريع
log "اختبار الاتصال كمستخدم التطبيق…"
PGPASSWORD="${APP_PASS}" psql -h 127.0.0.1 -U "${APP_USER}" -d "${DB_NAME}" -c "SELECT current_user, current_database();"

log "تمت إعادة البناء بنجاح."
