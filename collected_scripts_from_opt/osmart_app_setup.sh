#!/usr/bin/env bash
set -euo pipefail
[ "${EUID:-$(id -u)}" -eq 0 ] || { echo "[!] Run as root"; exit 1; }
export LC_ALL=C.UTF-8 LANG=C.UTF-8

# ===== Config =====
PG_HOST="${PG_HOST:-127.0.0.1}"
PG_PORT="${PG_PORT:-5432}"
PG_DB="${PG_DB:-osmart}"
PG_USER="${PG_USER:-osmart_app}"
PG_PASS="${PG_PASS:-Aa100200@@}"

APP_DIR="/opt/osmart"
VENV_DIR="${APP_DIR}/venv"
BIN_WRAPPER="/usr/local/bin/osmart"

log(){ echo "[*] $*"; }
pkg(){ dpkg -s "$1" &>/dev/null; }

need_install(){
  local miss=(); for p in "$@"; do pkg "$p" || miss+=("$p"); done
  if ((${#miss[@]})); then
    apt-get update -y
    DEBIAN_FRONTEND=noninteractive apt-get install -y "${miss[@]}"
  fi
}

# 0) System deps
log "Installing system deps…"
need_install python3-venv python3-pip tesseract-ocr libgl1 libjpeg-turbo8 libpng16-16 libtiff5

# 1) venv
mkdir -p "${APP_DIR}"
python3 -m venv "${VENV_DIR}"
"${VENV_DIR}/bin/pip" install --upgrade pip >/dev/null

# 2) Python deps
log "Installing Python deps…"
"${VENV_DIR}/bin/pip" install \
  psycopg2-binary pillow imagehash opencv-python-headless \
  pytesseract exifread python-dateutil tqdm >/dev/null

# 3) CLI script
cat >"${APP_DIR}/osmart_cli.py" <<'PY'
#!/usr/bin/env python3
import argparse, os, sys, json, hashlib, time, re, shutil
from datetime import datetime, timezone
from pathlib import Path
import psycopg2, psycopg2.extras
from PIL import Image, ImageOps, ImageEnhance
import imagehash, pytesseract, exifread
from dateutil import parser as dtp

# ---- DB connection ----
def db_connect():
    cfg = {
        "host": os.getenv("OSMART_DB_HOST","127.0.0.1"),
        "port": int(os.getenv("OSMART_DB_PORT","5432")),
        "dbname": os.getenv("OSMART_DB_NAME","osmart"),
        "user": os.getenv("OSMART_DB_USER","osmart_app"),
        "password": os.getenv("OSMART_DB_PASS","Aa100200@@"),
    }
    return psycopg2.connect(**cfg)

def list_public_tables(cur):
    cur.execute("""SELECT table_name
                   FROM information_schema.tables
                   WHERE table_schema='public' AND table_type='BASE TABLE'
                   ORDER BY table_name""")
    return [r[0] for r in cur.fetchall()]

def safe_table(cur, name):
    tabs = list_public_tables(cur)
    if name not in tabs:
        raise SystemExit(f"[!] Table not allowed: {name}")
    return '"' + name.replace('"','""') + '"'

def sha256_file(p: Path)->str:
    h = hashlib.sha256()
    with p.open('rb') as f:
        for chunk in iter(lambda: f.read(1<<20), b''):
            h.update(chunk)
    return h.hexdigest()

def exif_datetime(path: Path):
    try:
        with path.open('rb') as f:
            tags = exifread.process_file(f, details=False, stop_tag="EXIF DateTimeOriginal")
        for k in ("EXIF DateTimeOriginal","Image DateTime","EXIF DateTimeDigitized"):
            if k in tags:
                # format: "YYYY:MM:DD HH:MM:SS"
                txt = str(tags[k]).replace(":", "-", 2)
                return dtp.parse(txt).astimezone(timezone.utc)
    except Exception:
        pass
    try:
        ts = path.stat().st_mtime
        return datetime.fromtimestamp(ts, tz=timezone.utc)
    except Exception:
        return None

def ensure_item_training_table(cur, item_id:int):
    tname = f'تدريب_العنصر_{item_id}'
    cur.execute("""SELECT 1 FROM information_schema.tables
                   WHERE table_schema='public' AND table_name=%s""",(tname,))
    if not cur.fetchone():
        cur.execute(f'''
          CREATE TABLE public."{tname}"(
            "هاش" TEXT PRIMARY KEY,
            "نوع_العملية" TEXT NOT NULL,
            "معلمات" JSONB,
            "نقاط" REAL DEFAULT 0,
            "ثقة" REAL DEFAULT 0,
            "تاريخ" TIMESTAMPTZ DEFAULT now(),
            "مسار" TEXT
          );
          CREATE INDEX "{tname}_op_idx" ON public."{tname}"("نوع_العملية");
        ''')
    return tname

# ---- Commands ----
def cmd_ping(args):
    with db_connect() as con:
        with con.cursor() as cur:
            cur.execute("SELECT current_user, current_database();")
            u, d = cur.fetchone()
            print(json.dumps({"ok":True,"user":u,"db":d}, ensure_ascii=False))

def cmd_tables(args):
    with db_connect() as con:
        with con.cursor() as cur:
            print(json.dumps(list_public_tables(cur), ensure_ascii=False))

def cmd_query(args):
    with db_connect() as con:
        with con.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            t = safe_table(cur, args.table)
            sql = f'SELECT * FROM {t} ORDER BY 1 LIMIT %s OFFSET %s'
            cur.execute(sql, (args.limit, args.offset))
            rows = cur.fetchall()
            print(json.dumps(rows, ensure_ascii=False, default=str))

def cmd_delete(args):
    with db_connect() as con:
        with con.cursor() as cur:
            t = safe_table(cur, args.table)
            col = '"' + args.pk_col.replace('"','""') + '"'
            sql = f'DELETE FROM {t} WHERE {col}=%s'
            cur.execute(sql, (args.pk_val,))
        con.commit()
    print(json.dumps({"deleted":True}, ensure_ascii=False))

def cmd_upsert_item(args):
    with db_connect() as con:
        with con.cursor() as cur:
            # دعم جدولين: اسماء_العناصر أو عناصر_اللعبة ( fallback )
            cur.execute("""SELECT table_name FROM information_schema.tables
                           WHERE table_schema='public' AND table_name IN ('اسماء_العناصر','عناصر_اللعبة')""")
            row = cur.fetchone()
            if not row: raise SystemExit("[!] لا يوجد جدول للعناصر.")
            tname = row[0]
            t = '"' + tname + '"'
            cur.execute(f'''INSERT INTO public.{t}("id","الاسم_عربي","الاسم_إنجليزي","وزن_الرهان")
                            VALUES(%s,%s,%s,%s)
                            ON CONFLICT("id") DO UPDATE SET
                              "الاسم_عربي"=EXCLUDED."الاسم_عربي",
                              "الاسم_إنجليزي"=EXCLUDED."الاسم_إنجليزي",
                              "وزن_الرهان"=EXCLUDED."وزن_الرهان"''',
                        (args.id, args.ar, args.en, args.bet))
        con.commit()
    print(json.dumps({"upserted":args.id}, ensure_ascii=False))

def iter_images(root: Path):
    exts = {'.jpg','.jpeg','.png','.webp','.bmp','.tif','.tiff'}
    for p in root.rglob('*'):
        if p.is_file() and p.suffix.lower() in exts:
            yield p

def cmd_scan_import(args):
    root = Path(args.dir).expanduser().resolve()
    if not root.exists(): raise SystemExit(f"[!] Not found: {root}")
    total = sum(1 for _ in iter_images(root))
    done = 0
    with db_connect() as con:
        with con.cursor() as cur:
            for p in iter_images(root):
                try:
                    h = sha256_file(p)
                    size = p.stat().st_size
                    dt = exif_datetime(p)
                    cur.execute('''INSERT INTO public."عدم_التكرار"("هاش","حجم","تاريخ_الالتقاط")
                                   VALUES(%s,%s,%s)
                                   ON CONFLICT("هاش") DO NOTHING''', (h,size,dt))
                    cur.execute('''INSERT INTO public."حالة_الفحص"("هاش","الحالة","مسار")
                                   VALUES(%s,COALESCE((SELECT 'none'), 'none'),%s)
                                   ON CONFLICT("هاش") DO UPDATE SET "مسار"=EXCLUDED."مسار"''', (h,str(p)))
                    done += 1
                    if done % 20 == 0:
                        print(f"PROGRESS:{done}/{total}", flush=True)
                except Exception as e:
                    print(f"WARN:{p}:{e}", file=sys.stderr)
        con.commit()
    print(f"PROGRESS:{done}/{total}")
    print(json.dumps({"imported":done,"total":total}, ensure_ascii=False))

def load_image(path: Path):
    return Image.open(path).convert('RGBA')

def save_and_register(con, cur, img: Image.Image, out_path: Path, meta: dict, tname: str):
    out_path.parent.mkdir(parents=True, exist_ok=True)
    img.save(out_path, format="PNG")
    h = sha256_file(out_path)
    size = out_path.stat().st_size
    cur.execute('''INSERT INTO public."عدم_التكرار"("هاش","حجم","تاريخ_الالتقاط")
                   VALUES(%s,%s,now()) ON CONFLICT("هاش") DO NOTHING''', (h,size))
    cur.execute('''INSERT INTO public."حالة_الفحص"("هاش","الحالة","مسار")
                   VALUES(%s,'ok',%s)
                   ON CONFLICT("هاش") DO UPDATE SET "مسار"=EXCLUDED."مسار","الحالة"='ok' ''', (h,str(out_path)))
    cur.execute(f'''INSERT INTO public."{tname}"("هاش","نوع_العملية","معلمات","نقاط","ثقة","مسار")
                    VALUES(%s,%s,%s,%s,%s,%s)
                    ON CONFLICT("هاش") DO NOTHING''',
                (h,"augment",json.dumps(meta, ensure_ascii=False),1.0,0.5,str(out_path)))
    return h

def augment_all(img: Image.Image):
    out = []
    base = img
    # قياسات أساسية
    variants = [
        ("orig", {}),
        ("gray", {"gray":True}),
        ("bright07", {"brightness":0.7}),
        ("bright13", {"brightness":1.3}),
        ("contr08", {"contrast":0.8}),
        ("contr12", {"contrast":1.2}),
        ("rot90", {"rotate":90}),
        ("rot180", {"rotate":180}),
        ("rot270", {"rotate":270}),
        ("flip_h", {"flip":"H"}),
        ("flip_v", {"flip":"V"}),
        ("scale80", {"scale":0.8}),
        ("scale120", {"scale":1.2}),
    ]
    for name, m in variants:
        im = base.copy()
        if m.get("gray"): im = ImageOps.grayscale(im).convert('RGBA')
        if "brightness" in m: im = ImageEnhance.Brightness(im).enhance(m["brightness"])
        if "contrast"   in m: im = ImageEnhance.Contrast(im).enhance(m["contrast"])
        if "rotate"     in m: im = im.rotate(m["rotate"], expand=True)
        if m.get("flip")=="H": im = ImageOps.mirror(im)
        if m.get("flip")=="V": im = ImageOps.flip(im)
        if "scale" in m:
            w,h = im.size; s=m["scale"]; im = im.resize((max(1,int(w*s)), max(1,int(h*s))))
        out.append((name, m, im))
    return out

def cmd_make_experience(args):
    item_id = int(args.item_id)
    src_dir = Path(args.icons_dir).expanduser().resolve()
    if not src_dir.exists(): raise SystemExit(f"[!] Not found: {src_dir}")
    out_dir = Path(args.out_dir or f"/opt/osmart/data/train/{item_id}").resolve()
    with db_connect() as con, con.cursor() as cur:
        tname = ensure_item_training_table(cur, item_id)
        n_total = 0
        for img_path in iter_images(src_dir):
            try:
                base = load_image(img_path)
                packs = augment_all(base)
                for tag, meta, im in packs:
                    outp = out_dir / (img_path.stem + f"_{tag}.png")
                    save_and_register(con, cur, im, outp, {"src":str(img_path), **meta}, tname)
                    n_total += 1
                    if n_total % 20 == 0:
                        print(f"PROGRESS:{n_total}", flush=True)
            except Exception as e:
                print(f"WARN:{img_path}:{e}", file=sys.stderr)
        con.commit()
    print(json.dumps({"augmented": n_total}, ensure_ascii=False))

def cmd_ensure_partition(args):
    with db_connect() as con, con.cursor() as cur:
        tname = ensure_item_training_table(cur, int(args.item_id))
        con.commit()
    print(json.dumps({"table": tname}, ensure_ascii=False))

def phash_of(path: Path):
    with Image.open(path) as im:
        im = im.convert('RGB')
        return imagehash.phash(im)

def cmd_recognize_icon(args):
    target = Path(args.img).expanduser().resolve()
    if not target.exists(): raise SystemExit(f"[!] Not found: {target}")
    target_h = phash_of(target)
    icons_root = Path(args.icons_root or "/opt/osmart/icons")
    best = None
    for p in icons_root.rglob('*'):
        if p.is_file() and p.suffix.lower() in {'.png','.jpg','.jpeg','.webp'}:
            try:
                d = target_h - phash_of(p)
                if (best is None) or (d < best[0]):
                    best = (d, str(p))
            except Exception:
                pass
    if best is None:
        print(json.dumps({"match":None}, ensure_ascii=False)); return
    # استنباط item_id من المسار لو بالشكل /icons/<item_id>/file
    m = re.search(r'/(\d+)/[^/]+$', best[1])
    item_id = int(m.group(1)) if m else None
    print(json.dumps({"distance": best[0], "path": best[1], "item_id": item_id}, ensure_ascii=False))

def cmd_round_detect(args):
    img = Path(args.img).expanduser().resolve()
    if not img.exists(): raise SystemExit(f"[!] Not found: {img}")
    text = pytesseract.image_to_string(str(img), lang="eng+ara")
    # محاولة استخراج رقم الجولة
    m = re.search(r'(?:جولة|round)\D{0,3}(\d+)', text, flags=re.I)
    rnd = int(m.group(1)) if m else None
    print(json.dumps({"text": text.strip(), "round": rnd}, ensure_ascii=False))

def cmd_ocr_run(args):
    root = Path(args.dir).expanduser().resolve()
    out = Path(args.out or "/opt/osmart/ocr_out.json")
    res = []
    for p in iter_images(root):
        try:
            t = pytesseract.image_to_string(str(p), lang="eng+ara")
            res.append({"path": str(p), "text": t})
            if len(res)%20==0: print(f"PROGRESS:{len(res)}", flush=True)
        except Exception as e:
            res.append({"path": str(p), "error": str(e)})
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(res, ensure_ascii=False))
    print(json.dumps({"written": str(out), "count": len(res)}, ensure_ascii=False))

def main():
    ap = argparse.ArgumentParser(prog="osmart", description="OSMART server-side CLI (no background jobs).")
    sub = ap.add_subparsers(dest="cmd", required=True)

    sub.add_parser("ping")
    sub.add_parser("tables")
    q = sub.add_parser("query"); q.add_argument("--table", required=True); q.add_argument("--limit", type=int, default=100); q.add_argument("--offset", type=int, default=0)
    d = sub.add_parser("delete"); d.add_argument("--table", required=True); d.add_argument("--pk-col", required=True); d.add_argument("--pk-val", required=True)
    u = sub.add_parser("upsert-item"); u.add_argument("--id", type=int, required=True); u.add_argument("--ar", required=True); u.add_argument("--en", required=True); u.add_argument("--bet", type=int, required=True)

    si = sub.add_parser("scan-import"); si.add_argument("--dir", required=True)

    ep = sub.add_parser("ensure-partition"); ep.add_argument("--item-id", required=True)

    mx = sub.add_parser("make-experience"); mx.add_argument("--item-id", required=True); mx.add_argument("--icons-dir", required=True); mx.add_argument("--out-dir")

    rg = sub.add_parser("recognize-icon"); rg.add_argument("--img", required=True); rg.add_argument("--icons-root")

    rd = sub.add_parser("round-detect"); rd.add_argument("--img", required=True)

    oc = sub.add_parser("ocr-run"); oc.add_argument("--dir", required=True); oc.add_argument("--out")

    args = ap.parse_args()
    if args.cmd=="ping": cmd_ping(args)
    elif args.cmd=="tables": cmd_tables(args)
    elif args.cmd=="query": cmd_query(args)
    elif args.cmd=="delete": cmd_delete(args)
    elif args.cmd=="upsert-item": cmd_upsert_item(args)
    elif args.cmd=="scan-import": cmd_scan_import(args)
    elif args.cmd=="ensure-partition": cmd_ensure_partition(args)
    elif args.cmd=="make-experience": cmd_make_experience(args)
    elif args.cmd=="recognize-icon": cmd_recognize_icon(args)
    elif args.cmd=="round-detect": cmd_round_detect(args)
    elif args.cmd=="ocr-run": cmd_ocr_run(args)

if __name__ == "__main__":
    main()
PY

chmod +x "${APP_DIR}/osmart_cli.py"

# 4) wrapper
cat >"${BIN_WRAPPER}" <<'SH'
#!/usr/bin/env bash
export LC_ALL=C.UTF-8 LANG=C.UTF-8
export OSMART_DB_HOST="${OSMART_DB_HOST:-127.0.0.1}"
export OSMART_DB_PORT="${OSMART_DB_PORT:-5432}"
export OSMART_DB_NAME="${OSMART_DB_NAME:-osmart}"
export OSMART_DB_USER="${OSMART_DB_USER:-osmart_app}"
export OSMART_DB_PASS="${OSMART_DB_PASS:-Aa100200@@}"
exec /opt/osmart/venv/bin/python /opt/osmart/osmart_cli.py "$@"
SH
chmod +x "${BIN_WRAPPER}"

# 5) env helper (optional)
cat > /etc/osmart.env <<ENV
OSMART_DB_HOST=${PG_HOST}
OSMART_DB_PORT=${PG_PORT}
OSMART_DB_NAME=${PG_DB}
OSMART_DB_USER=${PG_USER}
OSMART_DB_PASS=${PG_PASS}
ENV

log "Done. Try: osmart ping"
