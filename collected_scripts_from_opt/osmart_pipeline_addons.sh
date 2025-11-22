#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "[!] خطأ في السطر $LINENO"; exit 1' ERR
[ "${EUID:-$(id -u)}" -eq 0 ] || { echo "[!] شغّلني كـ root"; exit 1; }
export LC_ALL=C.UTF-8 LANG=C.UTF-8

# ===== إعدادات أساسية =====
PG_DB="${PG_DB:-osmart}"          # اسم القاعدة
APP_DIR="/opt/osmart"
VENV="${APP_DIR}/venv"
BIN_DIR="${APP_DIR}/bin"
mkdir -p "$BIN_DIR"

echo "[*] Python deps (pytesseract/Pillow/psycopg2-binary)…"
/opt/osmart/venv/bin/python -m pip install --upgrade pip >/dev/null 2>&1 || true
/opt/osmart/venv/bin/pip install -q pytesseract Pillow "psycopg2-binary>=2.9,<3" || {
  echo "[!] تأكد أن الـ venv في $VENV موجود"; exit 1; }

echo "[*] SQL: إنشاء/تحديث الجداول والمؤشرات…"
sudo -u postgres psql -d "$PG_DB" -v "ON_ERROR_STOP=1" <<'SQL'
-- جدول الإعدادات (تشغيل/إيقاف من الواجهة فقط)
CREATE TABLE IF NOT EXISTS public."الإعدادات"(
  "مفتاح" TEXT PRIMARY KEY,
  "قيمة"  JSONB,
  "processing_enabled" BOOLEAN DEFAULT FALSE
);
INSERT INTO public."الإعدادات"("مفتاح","processing_enabled")
VALUES ('processing_enabled', FALSE)
ON CONFLICT ("مفتاح") DO NOTHING;

-- طابور الوظائف
CREATE TABLE IF NOT EXISTS public."الوظائف"(
  "id"        BIGSERIAL PRIMARY KEY,
  "هاش"      TEXT NOT NULL REFERENCES public."عدم_التكرار"("هاش") ON DELETE CASCADE,
  "المرحلة"  TEXT NOT NULL CHECK ("المرحلة" IN ('ocr','icon','save')),
  "الحالة"   TEXT NOT NULL CHECK ("الحالة" IN ('queued','running','done','error','skipped')) DEFAULT 'queued',
  "محاولات"  INT  NOT NULL DEFAULT 0,
  "خطأ"      TEXT,
  "أنشئ_في"  TIMESTAMPTZ NOT NULL DEFAULT now(),
  "حدث_في"   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS "الوظائف_status_idx" ON public."الوظائف"("الحالة","أنشئ_في");
CREATE INDEX IF NOT EXISTS "الوظائف_hash_idx"   ON public."الوظائف"("هاش");

-- trigger لتحديث "حدث_في"
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_proc  WHERE proname='trg_touch_jobs') THEN
    CREATE OR REPLACE FUNCTION public.trg_touch_jobs()
    RETURNS TRIGGER AS $f$
    BEGIN NEW."حدث_في" = now(); RETURN NEW; END
    $f$ LANGUAGE plpgsql;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='trg_jobs_touch_updated') THEN
    CREATE TRIGGER trg_jobs_touch_updated
    BEFORE UPDATE ON public."الوظائف"
    FOR EACH ROW EXECUTE FUNCTION public.trg_touch_jobs();
  END IF;
END $$;

-- فهرس للحالة في جدول حالة_الفحص
CREATE INDEX IF NOT EXISTS "حالة_الفحص_الحالة_idx" ON public."حالة_الفحص"("الحالة");

-- منع تكرار الخبرات في جداول تدريب_العنصر_*
DO $$
DECLARE r record; stmt text;
BEGIN
  FOR r IN SELECT tablename FROM pg_tables
           WHERE schemaname='public' AND tablename LIKE 'تدريب_العنصر_%'
  LOOP
    stmt := format('CREATE UNIQUE INDEX IF NOT EXISTS %I ON public.%I ("هاش","نوع_العملية", md5((%I)::text))',
                   r.tablename||'_uniq_exp', r.tablename, 'معلمات');
    EXECUTE stmt;
  END LOOP;
END $$;
SQL

echo "[*] عامل OCR (osmart_worker.py)…"
cat >"${APP_DIR}/osmart_worker.py"<<'PY'
#!/usr/bin/env python3
import os, re, json, time, psycopg2, pytesseract
from PIL import Image

PG = dict(
  host=os.environ.get("PG_HOST","127.0.0.1"),
  port=int(os.environ.get("PG_PORT","5432")),
  dbname=os.environ.get("PG_DB","osmart"),
  user=os.environ.get("PG_USER","osmart_app"),
  password=os.environ.get("PG_PASS","Aa100200@@"),
)
OCR_LANG = os.environ.get("OCR_LANG","ara+eng")

def one_job(conn):
  with conn:
    with conn.cursor() as cur:
      cur.execute('SELECT COALESCE(MAX(processing_enabled),false) FROM public."الإعدادات" WHERE "مفتاح"=$$processing_enabled$$')
      if not cur.fetchone()[0]:
        return None, "disabled"
      cur.execute("""
        SELECT j.id, j."هاش", hf."مسار"
        FROM public."الوظائف" j
        JOIN public."حالة_الفحص" hf ON hf."هاش"=j."هاش"
        WHERE j."الحالة"='queued' AND j."المرحلة"='ocr'
        ORDER BY j."أنشئ_في" ASC
        FOR UPDATE SKIP LOCKED
        LIMIT 1
      """)
      row = cur.fetchone()
      if not row: return None, "empty"
      jid, h, path = row
      cur.execute('UPDATE public."الوظائف" SET "الحالة"=$$running$$, "محاولات"="محاولات"+1 WHERE id=%s', (jid,))
      return dict(id=jid, hash=h, path=path), "ok"

def extract_round(txt:str):
  m = re.search(r'(\d{1,3})', txt)
  return int(m.group(1)) if m else None

def ocr_text(path)->str:
  img = Image.open(path)
  return pytesseract.image_to_string(img, lang=OCR_LANG)

def process_ocr(conn, job):
  h, p = job["hash"], job["path"]
  if not p or not os.path.exists(p): raise FileNotFoundError(p)
  text = ocr_text(p)
  round_no = extract_round(text)
  with conn:
    with conn.cursor() as cur:
      cur.execute('SELECT "تاريخ_الالتقاط" FROM public."عدم_التكرار" WHERE "هاش"=%s', (h,))
      cap = cur.fetchone()
      cap_ts = cap[0] if cap else None
      cur.execute("""
        INSERT INTO public."النتائج_اليومية"
          ("هاش","تاريخ_الالتقاط","رقم_الجولة","اسم_الأيقونة","شريط_اقتصاص","جملة_الشرط","الصف_كامل","نتيجة_الجولة")
        VALUES (%s,%s,%s,NULL,NULL,%s,NULL,NULL)
        ON CONFLICT ("هاش") DO NOTHING
      """, (h, cap_ts, round_no, text[:2000]))

def finish_job(conn, jid, status, err=None):
  with conn:
    with conn.cursor() as cur:
      if status=="done":
        cur.execute('UPDATE public."الوظائف" SET "الحالة"=$$done$$,"خطأ"=NULL WHERE id=%s', (jid,))
      else:
        cur.execute('UPDATE public."الوظائف" SET "الحالة"=%s,"خطأ"=%s WHERE id=%s', (status, err, jid))

def main_loop(batch:int=1, sleep_sec:float=0.0):
  conn = psycopg2.connect(**PG)
  try:
    processed=0
    while processed<batch:
      job, st = one_job(conn)
      if st in ("disabled","empty"):
        print(json.dumps({"status":st})); break
      try:
        process_ocr(conn, job)
        finish_job(conn, job["id"], "done")
        print(json.dumps({"ok":True,"job_id":job["id"],"hash":job["hash"]}))
      except Exception as e:
        finish_job(conn, job["id"], "error", str(e))
        print(json.dumps({"ok":False,"job_id":job["id"],"error":str(e)}))
      processed+=1
      if sleep_sec>0: time.sleep(sleep_sec)
  finally:
    conn.close()

if __name__=="__main__":
  import argparse
  ap=argparse.ArgumentParser()
  ap.add_argument("--batch", type=int, default=1)
  ap.add_argument("--sleep", type=float, default=0.0)
  args=ap.parse_args()
  main_loop(args.batch, args.sleep)
PY
chmod +x "${APP_DIR}/osmart_worker.py"

echo "[*] ماسح مجلد واستيراد (osmart_scan_import.sh)…"
cat >"${BIN_DIR}/osmart_scan_import.sh"<<'BASH'
#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "[!] خطأ في السطر $LINENO"; exit 1' ERR
DIR="${1:-}"; [ -n "$DIR" ] || { echo "[!] استخدم: $0 /path/to/images"; exit 1; }
shopt -s nullglob
FILES=("$DIR"/*.jpg "$DIR"/*.jpeg "$DIR"/*.png "$DIR"/*.bmp "$DIR"/*.webp)
[ ${#FILES[@]} -gt 0 ] || { echo "[!] لا توجد صور"; exit 0; }
pg(){ sudo -u postgres psql -d osmart -v "ON_ERROR_STOP=1" -At -c "$1"; }

for f in "${FILES[@]}"; do
  size=$(stat -c%s "$f")
  sha=$(sha1sum "$f" | awk '{print $1}')
  base=$(basename "$f")
  if [[ "$base" =~ ([0-9]{8})([0-9]{6}) ]]; then
    dt="${BASH_REMATCH[1]}${BASH_REMATCH[2]}"
    cap="$(date -d "${dt:0:4}-${dt:4:2}-${dt:6:2} ${dt:8:2}:${dt:10:2}:${dt:12:2}" -Is)"
  elif [[ "$base" =~ ([0-9]{8}) ]]; then
    d="${BASH_REMATCH[1]}"; cap="$(date -d "${d:0:4}-${d:4:2}-${d:6:2}" -Is)"
  else
    cap="$(date -d @$(stat -c %Y "$f") -Is)"
  fi
  escf="${f//\'/''}"

  pg "INSERT INTO public.\"عدم_التكرار\"(\"هاش\",\"حجم\",\"تاريخ_الالتقاط\")
      VALUES ('$sha',$size,'$cap') ON CONFLICT (\"هاش\") DO NOTHING;"

  pg "INSERT INTO public.\"حالة_الفحص\"(\"هاش\",\"الحالة\",\"مسار\")
      VALUES ('$sha','none','$escf')
      ON CONFLICT (\"هاش\") DO UPDATE SET \"مسار\"=EXCLUDED.\"مسار\";"

  pg "INSERT INTO public.\"الوظائف\"(\"هاش\",\"المرحلة\")
      SELECT '$sha','ocr'
      WHERE NOT EXISTS (
        SELECT 1 FROM public.\"الوظائف\"
        WHERE \"هاش\"='$sha' AND \"المرحلة\"='ocr' AND \"الحالة\" IN ('queued','running')
      );"
  echo " + queued OCR: $base"
done
BASH
chmod +x "${BIN_DIR}/osmart_scan_import.sh"
ln -sf "${BIN_DIR}/osmart_scan_import.sh" /usr/local/bin/osmart_scan_import.sh

echo "[*] أوامر مختصرة (osmart-job)…"
cat >/usr/local/bin/osmart-job<<'BASH'
#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "[!] خطأ في السطر $LINENO"; exit 1' ERR
PG_DB="${PG_DB:-osmart}"
pg(){ sudo -u postgres psql -d "$PG_DB" -v "ON_ERROR_STOP=1" -At -c "$1"; }

case "${1:-}" in
  enable)  pg "INSERT INTO public.\"الإعدادات\"(\"مفتاح\",\"processing_enabled\") VALUES ('processing_enabled',true)
                 ON CONFLICT (\"مفتاح\") DO UPDATE SET \"processing_enabled\"=EXCLUDED.\"processing_enabled\""; echo "on";;
  disable) pg "UPDATE public.\"الإعدادات\" SET \"processing_enabled\"=false WHERE \"مفتاح\"='processing_enabled'"; echo "off";;
  status)  pg "SELECT 'processing_enabled='||processing_enabled FROM public.\"الإعدادات\" WHERE \"مفتاح\"='processing_enabled'";;
  queue-dir)
           shift; dir="${1:-}"; [ -n "$dir" ] || { echo "[!] استخدم: osmart-job queue-dir /path"; exit 1; }
           /opt/osmart/bin/osmart_scan_import.sh "$dir";;
  one)     PG_HOST=127.0.0.1 PG_DB="$PG_DB" PG_USER=osmart_app PG_PASS="Aa100200@@" /opt/osmart/osmart_worker.py --batch 1;;
  batch)   shift; n="${1:-10}"; PG_HOST=127.0.0.1 PG_DB="$PG_DB" PG_USER=osmart_app PG_PASS="Aa100200@@" /opt/osmart/osmart_worker.py --batch "$n";;
  *) echo "استخدام:
  osmart-job enable|disable|status
  osmart-job queue-dir /path/to/images
  osmart-job one
  osmart-job batch N"; exit 1;;
esac
BASH
chmod +x /usr/local/bin/osmart-job

echo "[*] جاهز. لا تشغيل تلقائي دائم على السيرفر؛ التحكم من الواجهة/الأوامر فقط."
echo "  osmart-job status"
echo "  osmart-job enable"
echo "  osmart-job queue-dir /path/to/images"
echo "  osmart-job one   # تنفيذ وظيفة واحدة"
echo "  osmart-job batch 5"
