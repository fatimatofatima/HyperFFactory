#!/usr/bin/env bash
set -euo pipefail

# ===== إعدادات قابلة للتعديل =====
PG_VER="${PG_VER:-16}"
DB_NAME="${DB_NAME:-osmart}"
SUPER_USER="${SUPER_USER:-root}"
SUPER_PASS="${SUPER_PASS:-Aa100200@@}"
APP_USER="${APP_USER:-osmart_app}"
APP_PASS="${APP_PASS:-Aa100200@@}"

OSMART_DIR="/opt/osmart"
VENV_DIR="${OSMART_DIR}/venv"
BIN_DIR="${OSMART_DIR}/bin"

PG_ETC="/etc/postgresql/${PG_VER}/main"
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

ensure_line() { # ensure_line <file> <regex_to_check> <line_to_append>
  local f="$1" re="$2" line="$3"
  grep -Eq "$re" "$f" 2>/dev/null || echo "$line" >>"$f"
}

# ===== 0) متطلبات ونُصُب Postgres 16 + TimescaleDB =====
log "تحضير المتطلبات…"
need_install curl ca-certificates gnupg lsb-release software-properties-common python3 python3-venv python3-pip

install -d -m 0755 /etc/apt/keyrings
if [ ! -f /etc/apt/keyrings/pgdg.gpg ]; then
  curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /etc/apt/keyrings/pgdg.gpg
fi
ensure_line /etc/apt/sources.list.d/pgdg.list '^deb .*apt.postgresql.org' \
"deb [signed-by=/etc/apt/keyrings/pgdg.gpg] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main"

# TimescaleDB repo
if [ ! -f /usr/share/keyrings/timescaledb.gpg ]; then
  curl -fsSL https://packagecloud.io/timescale/timescaledb/gpgkey | gpg --dearmor -o /usr/share/keyrings/timescaledb.gpg
fi
ensure_line /etc/apt/sources.list.d/timescaledb.list '^deb .*packagecloud.io/timescale/timescaledb' \
"deb [signed-by=/usr/share/keyrings/timescaledb.gpg] https://packagecloud.io/timescale/timescaledb/ubuntu/ $(lsb_release -cs) main"

apt-get update -y
need_install "postgresql-${PG_VER}" "postgresql-client-${PG_VER}" "timescaledb-2-postgresql-${PG_VER}"

systemctl enable --now postgresql

# ===== 1) تفعيل timescaledb و SCRAM على اللوكالهوست =====
log "تفعيل shared_preload_libraries=timescaledb…"
sudo -u postgres psql -v ON_ERROR_STOP=1 -c "ALTER SYSTEM SET shared_preload_libraries = 'timescaledb';" >/dev/null
sudo -u postgres psql -v ON_ERROR_STOP=1 -c "ALTER SYSTEM SET password_encryption = 'scram-sha-256';" >/dev/null
systemctl restart postgresql

log "تهيئة pg_hba.conf للمصادقة SCRAM على localhost…"
cp -a "$PG_HBA" "${PG_HBA}.bak.$(date +%s)" || true
ensure_line "$PG_HBA" '^[[:space:]]*host[[:space:]]+all[[:space:]]+all[[:space:]]+127\.0\.0\.1/32' "host  all  all  127.0.0.1/32  scram-sha-256"
ensure_line "$PG_HBA" '^[[:space:]]*host[[:space:]]+all[[:space:]]+all[[:space:]]+::1/128'        "host  all  all  ::1/128       scram-sha-256"
systemctl reload postgresql

# ===== 2) المستخدمين وقاعدة البيانات =====
log "إنشاء/تحديث المستخدمين ${SUPER_USER} و ${APP_USER}…"
sudo -u postgres psql -v ON_ERROR_STOP=1 <<SQL
SELECT pg_reload_conf();
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='${SUPER_USER}') THEN
    EXECUTE format('CREATE ROLE %I LOGIN SUPERUSER PASSWORD %L', '${SUPER_USER}', '${SUPER_PASS}');
  ELSE
    EXECUTE format('ALTER ROLE %I WITH LOGIN SUPERUSER PASSWORD %L', '${SUPER_USER}', '${SUPER_PASS}');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='${APP_USER}') THEN
    EXECUTE format('CREATE ROLE %I LOGIN PASSWORD %L', '${APP_USER}', '${APP_PASS}');
  ELSE
    EXECUTE format('ALTER ROLE %I WITH LOGIN PASSWORD %L', '${APP_USER}', '${APP_PASS}');
  END IF;
END
\$\$;
SQL

log "إعادة إنشاء قاعدة ${DB_NAME}…"
if sudo -u postgres psql -Atqc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | grep -q 1; then
  sudo -u postgres psql -v ON_ERROR_STOP=1 -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='${DB_NAME}' AND pid<>pg_backend_pid();" >/dev/null || true
  sudo -u postgres psql -v ON_ERROR_STOP=1 -c "DROP DATABASE ${DB_NAME};"
fi
sudo -u postgres psql -v ON_ERROR_STOP=1 -c "CREATE DATABASE ${DB_NAME} WITH OWNER ${SUPER_USER} ENCODING 'UTF8' TEMPLATE template0;"

# ===== 3) الجداول المطلوبة + الدوال =====
log "إنشاء الجداول والدوال…"
sudo -u postgres psql -v ON_ERROR_STOP=1 -d "${DB_NAME}" <<'SQL'
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- 1) عدم_التكرار
CREATE TABLE IF NOT EXISTS "عدم_التكرار" (
  "هاش"            TEXT PRIMARY KEY,
  "حجم"            BIGINT NOT NULL CHECK ("حجم" >= 0),
  "تاريخ_الالتقاط" TIMESTAMPTZ
);

-- 2) حالة_الفحص
CREATE TABLE IF NOT EXISTS "حالة_الفحص" (
  "هاش"    TEXT PRIMARY KEY REFERENCES "عدم_التكرار"("هاش") ON DELETE CASCADE,
  "الحالة" TEXT NOT NULL CHECK ("الحالة" IN ('none','ok','rejec','path'))
);

-- 3) اسماء_العناصر
CREATE TABLE IF NOT EXISTS "اسماء_العناصر" (
  "id"             INT PRIMARY KEY,
  "الاسم_عربي"    TEXT NOT NULL,
  "الاسم_انجليزي" TEXT NOT NULL,
  "وزن_الرهان"    INT  NOT NULL
);

-- 4) النتائج_اليومية
CREATE TABLE IF NOT EXISTS "النتائج_اليومية" (
  "هاش"            TEXT NOT NULL REFERENCES "عدم_التكرار"("هاش") ON DELETE CASCADE,
  "تاريخ_الالتقاط" TIMESTAMPTZ,
  "رقم_الجولة"     INT,
  "اسم_الأيقونة"   TEXT,
  "شريط_اقتصاص"    JSONB,
  "جملة_الشرط"     TEXT,
  "الصف_كامل"      JSONB,
  "نتيجة_الجولة"   TEXT
);
-- فهارس مفيدة
CREATE INDEX IF NOT EXISTS idx_نتائج_حسب_التاريخ ON "النتائج_اليومية" ("تاريخ_الالتقاط");
SELECT create_hypertable('"النتائج_اليومية"', 'تاريخ_الالتقاط', if_not_exists => TRUE);

-- دالة: upsert عدم_التكرار
CREATE OR REPLACE FUNCTION upsert_nondup(p_hash text, p_size bigint, p_taken timestamptz)
RETURNS void AS $$
BEGIN
  INSERT INTO "عدم_التكرار"("هاش","حجم","تاريخ_الالتقاط")
  VALUES (p_hash,p_size,p_taken)
  ON CONFLICT ("هاش") DO UPDATE
    SET "حجم"=EXCLUDED."حجم",
        "تاريخ_الالتقاط"=COALESCE(EXCLUDED."تاريخ_الالتقاط","عدم_التكرار"."تاريخ_الالتقاط");
END $$ LANGUAGE plpgsql;

-- دالة: ضبط حالة الفحص
CREATE OR REPLACE FUNCTION set_status(p_hash text, p_state text)
RETURNS void AS $$
BEGIN
  IF p_state NOT IN ('none','ok','rejec','path') THEN
    RAISE EXCEPTION 'state % not allowed', p_state;
  END IF;
  INSERT INTO "حالة_الفحص"("هاش","الحالة")
  VALUES (p_hash,p_state)
  ON CONFLICT ("هاش") DO UPDATE SET "الحالة"=EXCLUDED."الحالة";
END $$ LANGUAGE plpgsql;

-- دالة: إضافة نتيجة يومية
CREATE OR REPLACE FUNCTION add_daily_result(
  p_hash text, p_taken timestamptz, p_round int, p_icon text,
  p_crop jsonb, p_rule text, p_fullrow jsonb, p_result text)
RETURNS void AS $$
BEGIN
  INSERT INTO "النتائج_اليومية"(
    "هاش","تاريخ_الالتقاط","رقم_الجولة","اسم_الأيقونة",
    "شريط_اقتصاص","جملة_الشرط","الصف_كامل","نتيجة_الجولة")
  VALUES (p_hash,p_taken,p_round,p_icon,p_crop,p_rule,p_fullrow,p_result);
END $$ LANGUAGE plpgsql;

-- دالة: إنشاء جدول تدريب خاص بكل عنصر
CREATE OR REPLACE FUNCTION create_training_table(p_item_id int)
RETURNS void AS $$
DECLARE tname text := format('تدريب_العنصر_%s', p_item_id);
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_tables WHERE schemaname='public' AND tablename=tname
  ) THEN
    EXECUTE format($f$
      CREATE TABLE %I (
        "هاش"          TEXT PRIMARY KEY,
        "نوع_العملية"  TEXT NOT NULL,      -- base/rotate/scale/flip/…
        "معلمات"       JSONB,              -- تفاصيل التحويل
        "نقاط"         INT   DEFAULT 0,
        "ثقة"          NUMERIC(5,4),       -- 0..1
        "أُنشئ_في"     TIMESTAMPTZ DEFAULT now()
      );
      CREATE INDEX IF NOT EXISTS %I ON %I("نوع_العملية");
    $f$, tname, ('idx_'||tname||'_op'), tname);
  END IF;
END $$ LANGUAGE plpgsql;

-- دالة: إضافة عينة تدريب لعنصر
CREATE OR REPLACE FUNCTION add_training_sample(
  p_item_id int, p_hash text, p_op text, p_params jsonb, p_points int, p_conf numeric)
RETURNS void AS $$
DECLARE tname text := format('تدريب_العنصر_%s', p_item_id);
BEGIN
  PERFORM create_training_table(p_item_id);
  EXECUTE format('INSERT INTO %I("هاش","نوع_العملية","معلمات","نقاط","ثقة")
                  VALUES ($1,$2,$3,$4,$5)
                  ON CONFLICT ("هاش") DO NOTHING', tname)
  USING p_hash,p_op,p_params,COALESCE(p_points,0),p_conf;
END $$ LANGUAGE plpgsql;
SQL

# ===== 4) صلاحيات التطبيق =====
log "منح صلاحيات للتطبيق…"
sudo -u postgres psql -v ON_ERROR_STOP=1 -d "${DB_NAME}" <<SQL
ALTER SCHEMA public OWNER TO ${SUPER_USER};
GRANT USAGE ON SCHEMA public TO ${APP_USER};
GRANT SELECT,INSERT,UPDATE,DELETE ON ALL TABLES IN SCHEMA public TO ${APP_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT,INSERT,UPDATE,DELETE ON TABLES TO ${APP_USER};
SQL

# ===== 5) بيئة بايثون + سكربتات السيرفر =====
log "إعداد سكربتات السيرفر (فحص مجلد/إدراج)…"
mkdir -p "${BIN_DIR}"

# venv
python3 -m venv "${VENV_DIR}"
"${VENV_DIR}/bin/pip" install --upgrade pip >/dev/null
"${VENV_DIR}/bin/pip" install pillow imagehash piexif psycopg2-binary >/dev/null

# osmart_scan_dir.py: يطبع JSONL (path,hash,size,captured_at)
cat > "${BIN_DIR}/osmart_scan_dir.py" <<'PY'
#!/usr/bin/env python3
import sys, os, hashlib, json, datetime, re
from PIL import Image, ExifTags

def sha256_file(p):
    h = hashlib.sha256()
    with open(p, 'rb') as f:
        for chunk in iter(lambda: f.read(1024*1024), b''):
            h.update(chunk)
    return h.hexdigest()

def get_exif_datetime(p):
    try:
        with Image.open(p) as im:
            exif = im.getexif()
            if not exif: return None
            for k,v in exif.items():
                tag = ExifTags.TAGS.get(k,k)
                if str(tag) in ("DateTimeOriginal","DateTime","DateTimeDigitized"):
                    s = str(v)
                    s = s.replace(':','-',2).replace(' ','T')  # "YYYY:MM:DD HH:MM:SS" -> "YYYY-MM-DDTHH:MM:SS"
                    return s
    except Exception:
        return None
    return None

def parse_date_from_name(name):
    # يحاول YYYYMMDD_HHMMSS أو YYYY-MM-DD_HH-MM-SS
    m = re.search(r'(20\d{2})[-_]?(\d{2})[-_]?(\d{2})[ _-]?(\d{2})[:_-]?(\d{2})[:_-]?(\d{2})', name)
    if m:
        return f"{m.group(1)}-{m.group(2)}-{m.group(3)}T{m.group(4)}:{m.group(5)}:{m.group(6)}"
    m = re.search(r'(20\d{2})[-_]?(\d{2})[-_]?(\d{2})', name)
    if m:
        return f"{m.group(1)}-{m.group(2)}-{m.group(3)}T00:00:00"
    return None

def is_image(fn):
    fnl = fn.lower()
    return any(fnl.endswith(ext) for ext in ('.jpg','.jpeg','.png','.bmp','.webp','.tif','.tiff'))

def main():
    if len(sys.argv)<2:
        print("usage: osmart_scan_dir.py <dir>", file=sys.stderr); sys.exit(2)
    root = sys.argv[1]
    for base, _, files in os.walk(root):
        for f in files:
            if not is_image(f): continue
            p = os.path.join(base,f)
            try:
                st = os.stat(p)
                size = st.st_size
                h = sha256_file(p)
                dt = get_exif_datetime(p) or parse_date_from_name(f)
                print(json.dumps({"path": p, "hash": h, "size": size, "captured_at": dt}, ensure_ascii=False))
            except Exception as e:
                print(json.dumps({"path": p, "error": str(e)}), file=sys.stderr)
if __name__ == "__main__":
    main()
PY
chmod +x "${BIN_DIR}/osmart_scan_dir.py"

# osmart_import_dir.py: يقرأ JSONL من stdin ويدخل DB
cat > "${BIN_DIR}/osmart_import_dir.py" <<'PY'
#!/usr/bin/env python3
import sys, json, os, psycopg2, psycopg2.extras
DB=os.environ.get("OS_DB_NAME","osmart")
USER=os.environ.get("OS_DB_USER","osmart_app")
PASS=os.environ.get("OS_DB_PASS","Aa100200@@")
HOST=os.environ.get("OS_DB_HOST","127.0.0.1")
PORT=int(os.environ.get("OS_DB_PORT","5432"))

conn = psycopg2.connect(dbname=DB, user=USER, password=PASS, host=HOST, port=PORT)
conn.autocommit = True

up1 = 'SELECT upsert_nondup(%s,%s,%s)'
up2 = 'INSERT INTO "حالة_الفحص"("هاش","الحالة") VALUES (%s,%s) ON CONFLICT ("هاش") DO NOTHING'

cur = conn.cursor()
for line in sys.stdin:
    line = line.strip()
    if not line: continue
    try:
        obj = json.loads(line)
        h   = obj["hash"]
        sz  = int(obj.get("size") or 0)
        dt  = obj.get("captured_at")  # قد يكون None
        cur.execute(up1, (h, sz, dt))
        cur.execute(up2, (h, 'none'))
    except Exception as e:
        print(f"[ERR] {e} :: {line}", file=sys.stderr)

cur.close(); conn.close()
PY
chmod +x "${BIN_DIR}/osmart_import_dir.py"

# wrapper: osmart_scan_import.sh
cat > "${BIN_DIR}/osmart_scan_import.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [ $# -lt 1 ]; then
  echo "usage: osmart_scan_import.sh <dir>"; exit 2
fi
DIR="$1"
THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export OS_DB_NAME="${OS_DB_NAME:-osmart}"
export OS_DB_USER="${OS_DB_USER:-osmart_app}"
export OS_DB_PASS="${OS_DB_PASS:-Aa100200@@}"
export OS_DB_HOST="${OS_DB_HOST:-127.0.0.1}"
export OS_DB_PORT="${OS_DB_PORT:-5432}"
"${THIS_DIR}/../venv/bin/python" "${THIS_DIR}/osmart_scan_dir.py" "$DIR" | \
"${THIS_DIR}/../venv/bin/python" "${THIS_DIR}/osmart_import_dir.py"
SH
chmod +x "${BIN_DIR}/osmart_scan_import.sh"

# روابط مريحة
install -m 0755 -D "${BIN_DIR}/osmart_scan_import.sh" /usr/local/bin/osmart_scan_import.sh

# ===== 6) اختبار اتصال كتطبيق =====
log "اختبار الاتصال كمستخدم التطبيق…"
PGPASSWORD="${APP_PASS}" psql -h 127.0.0.1 -U "${APP_USER}" -d "${DB_NAME}" -c "SELECT current_user, current_database();" >/dev/null

log "تم الإعداد. لاستخدام فحص مجلد صور:"
echo "  /osmart/bin/osmart_scan_import.sh /path/to/images"
