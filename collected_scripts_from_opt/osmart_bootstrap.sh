#!/usr/bin/env bash
set -euo pipefail

# ==== إعدادات قابلة للتغيير عبر متغيرات البيئة ====
DB_USER="${DB_USER:-osmart_app}"
DB_PASS="${DB_PASS:-ChangeMe_Strong#2025}"  # غيّرها
DB_NAME="${DB_NAME:-osmart}"
PG_VER="${PG_VER:-16}"

pg_list="/etc/apt/sources.list.d/pgdg.list"
pg_key="/etc/apt/keyrings/pgdg.gpg"

# أعلام
RECREATE_DB=false
while getopts ":r" opt; do
  case "$opt" in
    r) RECREATE_DB=true ;;
  esac
done

log(){ echo "[*] $*"; }

pkg_installed(){ dpkg -s "$1" &>/dev/null; }
need_install(){
  local miss=()
  for p in "$@"; do pkg_installed "$p" || miss+=("$p"); done
  if ((${#miss[@]})); then
    apt-get update -y
    DEBIAN_FRONTEND=noninteractive apt-get install -y "${miss[@]}"
  fi
}

# 1) متطلبات وPG مخزن رسمي مرة واحدة فقط
log "فحص المتطلبات..."
need_install curl ca-certificates gnupg lsb-release
install -d -m 0755 /etc/apt/keyrings
if [[ ! -f "$pg_key" ]]; then
  curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o "$pg_key"
fi
if [[ ! -f "$pg_list" ]]; then
  echo "deb [signed-by=$pg_key] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > "$pg_list"
  apt-get update -y
fi

# 2) PostgreSQL: ثبّت فقط إن كان مفقودًا
log "التأكد من PostgreSQL ${PG_VER}..."
need_install "postgresql-${PG_VER}" "postgresql-client-${PG_VER}"
systemctl enable --now postgresql

# 3) ضبط آمن ومحسّن بدون تكرار
PG_ETC="/etc/postgresql/${PG_VER}/main"
CONF_D="${PG_ETC}/conf.d"
mkdir -p "$CONF_D"
MEM_KB=$(awk '/MemTotal/{print $2}' /proc/meminfo)
SB_MB=$((MEM_KB/4/1024))         # ~25% RAM
ECS_MB=$((MEM_KB*7/10/1024))     # ~70% RAM
TMP_CONF=$(mktemp)
cat > "$TMP_CONF" <<CONF
# osmart tuned
listen_addresses = '127.0.0.1'
timezone = 'Asia/Kuwait'
log_timezone = 'Asia/Kuwait'
password_encryption = scram-sha-256
wal_compression = on
checkpoint_timeout = '15min'
max_wal_size = '2GB'
shared_buffers = ${SB_MB}MB
effective_cache_size = ${ECS_MB}MB
CONF
TARGET_CONF="${CONF_D}/osmart.conf"
if [[ ! -f "$TARGET_CONF" ]] || ! cmp -s "$TMP_CONF" "$TARGET_CONF"; then
  mv "$TMP_CONF" "$TARGET_CONF"
  chown postgres:postgres "$TARGET_CONF"; chmod 644 "$TARGET_CONF"
  systemctl restart postgresql
else
  rm -f "$TMP_CONF"
fi

# 4) الدور
log "إنشاء/تحديث دور ${DB_USER}..."
if sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}'" | grep -q 1; then
  sudo -u postgres psql -c "ALTER ROLE ${DB_USER} WITH LOGIN PASSWORD '${DB_PASS}'"
else
  sudo -u postgres psql -c "CREATE ROLE ${DB_USER} LOGIN PASSWORD '${DB_PASS}'"
fi

# 5) القاعدة
if $RECREATE_DB; then
  log "إعادة إنشاء قاعدة ${DB_NAME}..."
  if sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | grep -q 1; then
    sudo -u postgres psql -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='${DB_NAME}'"
    sudo -u postgres psql -c "DROP DATABASE ${DB_NAME}"
  fi
fi
if ! sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | grep -q 1; then
  sudo -u postgres psql -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER} ENCODING 'UTF8'"
fi
sudo -u postgres psql -d "${DB_NAME}" -c "ALTER DATABASE ${DB_NAME} SET timezone TO 'Asia/Kuwait'"

# 6) مخطط الجداول عبر STDIN لمنع مشاكل صلاحيات /root
log "تطبيق المخطط..."
sudo -u postgres psql -d "${DB_NAME}" -v ON_ERROR_STOP=1 <<'SQL'
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'qa_state') THEN
    CREATE TYPE qa_state AS ENUM ('غير_مفحوص','مقبول','مرفوض','تالف','فشل');
  END IF;
END$$;

CREATE TABLE IF NOT EXISTS "مخزن_المحتوى" (
  "بصمة_المحتوى"   BYTEA PRIMARY KEY,
  "حجم_الملف"       BIGINT NOT NULL,
  "تاريخ_الالتقاط" TIMESTAMPTZ,
  "مصدر_التاريخ"   TEXT CHECK ("مصدر_التاريخ" IN ('EXIF','اسم_الملف','غير_معروف'))
);

CREATE TABLE IF NOT EXISTS "حالة_الفحص" (
  "بصمة_المحتوى" BYTEA PRIMARY KEY
      REFERENCES "مخزن_المحتوى"("بصمة_المحتوى") ON DELETE CASCADE,
  "الحالة"       qa_state NOT NULL DEFAULT 'غير_مفحوص',
  "سبب_الحالة"   TEXT,
  "مسار_حالي"    TEXT,
  "وقت_التحديث"  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS "idx_حالة_الفحص_معلق"
  ON "حالة_الفحص"("بصمة_المحتوى")
  WHERE "الحالة" IN ('غير_مفحوص','فشل');

CREATE TABLE IF NOT EXISTS "بيانات_الاستخراج" (
  "بصمة_المحتوى"   BYTEA PRIMARY KEY
      REFERENCES "مخزن_المحتوى"("بصمة_المحتوى") ON DELETE CASCADE,
  "رقم_الجولة"     INTEGER,
  "اسم_الأيقونة"   TEXT,
  "نص_سطر_النتيجة" TEXT,
  "ثقة_OCR"        REAL,
  "زاوية_الدوران"  REAL,
  "حد_قص_X"        INTEGER,
  "حد_قص_Y"        INTEGER,
  "حد_قص_عرض"      INTEGER,
  "حد_قص_ارتفاع"   INTEGER
);
CREATE INDEX IF NOT EXISTS "idx_الاستخراج_الجولة" ON "بيانات_الاستخراج"("رقم_الجولة");

CREATE TABLE IF NOT EXISTS "سجل_الإجراءات" (
  "id"             BIGSERIAL PRIMARY KEY,
  "بصمة_المحتوى"  BYTEA NOT NULL
      REFERENCES "مخزن_المحتوى"("بصمة_المحتوى") ON DELETE CASCADE,
  "الإجراء"        TEXT NOT NULL,
  "التفاصيل"       TEXT,
  "وقت_الإجراء"    TIMESTAMPTZ NOT NULL DEFAULT now(),
  "منفذ_الإجراء"   TEXT
);
CREATE INDEX IF NOT EXISTS "idx_سجل_الإجراءات_البصمة" ON "سجل_الإجراءات"("بصمة_المحتوى");

CREATE TABLE IF NOT EXISTS "عناصر_اللعبة" (
  "معرف"                 INTEGER PRIMARY KEY,
  "اسم_العنصر_عربي"     TEXT NOT NULL UNIQUE,
  "اسم_العنصر_إنجليزي"  TEXT NOT NULL UNIQUE,
  "وزن_الرهان"           REAL NOT NULL
);

CREATE TABLE IF NOT EXISTS "أيقونات_العناصر" (
  "id"               BIGSERIAL PRIMARY KEY,
  "معرف_العنصر"     INTEGER NOT NULL
       REFERENCES "عناصر_اللعبة"("معرف") ON DELETE CASCADE,
  "خوارزمية_التجزئة" TEXT NOT NULL DEFAULT 'BLAKE3-256',
  "هاش_الأيقونة"     BYTEA NOT NULL,
  "phash64"          BIGINT,
  "عرض"              INTEGER,
  "ارتفاع"           INTEGER,
  "نوع_الأيقونة"     TEXT,
  "مسار_الأصل"       TEXT,
  "تاريخ_الإضافة"    TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE ("معرف_العنصر","هاش_الأيقونة")
);
CREATE INDEX IF NOT EXISTS "idx_أيقونات_العناصر_phash_bucket" ON "أيقونات_العناصر" ((phash64 >> 8));
CREATE INDEX IF NOT EXISTS "idx_أيقونات_العناصر_عنصر" ON "أيقونات_العناصر"("معرف_العنصر");

CREATE OR REPLACE FUNCTION add_icon(
  _معرف_العنصر INT,
  _هاش BYTEA,
  _phash BIGINT DEFAULT NULL,
  _عرض INT DEFAULT NULL,
  _ارتفاع INT DEFAULT NULL,
  _نوع TEXT DEFAULT NULL,
  _مسار TEXT DEFAULT NULL
) RETURNS BIGINT AS $$
DECLARE _id BIGINT;
BEGIN
  INSERT INTO "أيقونات_العناصر"
    ("معرف_العنصر","هاش_الأيقونة","phash64","عرض","ارتفاع","نوع_الأيقونة","مسار_الأصل")
  VALUES
    (_معرف_العنصر,_هاش,_phash,_عرض,_ارتفاع,_نوع,_مسار)
  ON CONFLICT ("معرف_العنصر","هاش_الأيقونة") DO UPDATE SET
    "phash64"=COALESCE(EXCLUDED."phash64","أيقونات_العناصر"."phash64"),
    "عرض"=COALESCE(EXCLUDED."عرض","أيقونات_العناصر"."عرض"),
    "ارتفاع"=COALESCE(EXCLUDED."ارتفاع","أيقونات_العناصر"."ارتفاع"),
    "نوع_الأيقونة"=COALESCE(EXCLUDED."نوع_الأيقونة","أيقونات_العناصر"."نوع_الأيقونة"),
    "مسار_الأصل"=COALESCE(EXCLUDED."مسار_الأصل","أيقونات_العناصر"."مسار_الأصل")
  RETURNING id INTO _id;
  RETURN _id;
END; $$ LANGUAGE plpgsql;
SQL

# 7) تحقق
sudo -u postgres psql -d "${DB_NAME}" -c "\dt"

log "تم."
