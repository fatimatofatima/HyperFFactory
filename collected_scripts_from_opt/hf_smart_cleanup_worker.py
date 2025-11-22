import os
import sqlite3
import hashlib
import argparse
import shutil
from datetime import datetime

def init_db(path: str) -> sqlite3.Connection:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    conn = sqlite3.connect(path)
    cur = conn.cursor()

    cur.execute("""
        CREATE TABLE IF NOT EXISTS files(
            id        INTEGER PRIMARY KEY,
            path      TEXT UNIQUE,
            size      INTEGER,
            mtime     REAL,
            md5       TEXT,
            family    TEXT,
            status    TEXT,
            cold_path TEXT,
            created_at TEXT
        )
    """)

    cur.execute("""
        CREATE TABLE IF NOT EXISTS actions(
            id     INTEGER PRIMARY KEY,
            path   TEXT,
            action TEXT,
            reason TEXT,
            ts     TEXT
        )
    """)

    conn.commit()
    return conn

def iter_candidates(root: str):
    exts = {".db", ".sqlite", ".sql", ".gz", ".zst", ".xz", ".tar", ".tgz", ".zip"}
    for dirpath, dirnames, filenames in os.walk(root):
        for name in filenames:
            ext = os.path.splitext(name)[1].lower()
            if ext in exts:
                yield os.path.join(dirpath, name)

def classify_family(name: str) -> str:
    lower = name.lower()
    if "smartfriend_unified" in lower:
        return "smartfriend_unified"
    if "smart_core" in lower and "memory" in lower:
        return "smart_core_memory"
    if "memory" in lower:
        return "memory"
    if "backup" in lower or "bkp" in lower:
        return "backup"
    if "snapshot" in lower:
        return "snapshot"
    return "misc"

def compute_md5(path: str, buf_size: int = 1024 * 1024) -> str:
    h = hashlib.md5()
    with open(path, "rb") as f:
        while True:
            chunk = f.read(buf_size)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()

def print_progress(done: int, total: int, prefix: str = ""):
    if total == 0:
        return
    bar_len = 40
    ratio = done / total
    filled = int(bar_len * ratio)
    bar = "#" * filled + "-" * (bar_len - filled)
    print(f"\r{prefix}[{bar}] {done}/{total} ({ratio*100:5.1f}%)", end="", flush=True)

def choose_canonical(paths):
    # أبسط سياسة: أقصر مسار (عادةً الأكثر "رسمية")
    return sorted(paths, key=lambda p: (len(p), p))[0]

def main():
    parser = argparse.ArgumentParser(description="Hyper-Factory Smart Cleanup Worker (MD5 + dedupe)")
    parser.add_argument("--root", required=True, help="جذر ملفات النسخ/قواعد البيانات")
    parser.add_argument("--db", required=True, help="مسار قاعدة بيانات الجرد الموحدة")
    parser.add_argument("--cold", required=True, help="مجلد cold_storage لنقل التكرارات")
    args = parser.parse_args()

    root = os.path.abspath(args.root)
    db_path = os.path.abspath(args.db)
    cold_dir = os.path.abspath(args.cold)

    os.makedirs(cold_dir, exist_ok=True)

    conn = init_db(db_path)
    cur = conn.cursor()

    print(f"Root directory : {root}")
    print(f"Cold storage   : {cold_dir}")
    print(f"Inventory DB   : {db_path}")
    print()

    print(">> جمع قائمة الملفات المستهدفة...")
    candidates = list(iter_candidates(root))
    total = len(candidates)
    print(f"عدد الملفات المرشحة: {total}")
    if total == 0:
        print("لا توجد ملفات لمعالجتها.")
        return

    hash_map = {}  # md5 -> [paths]
    processed = 0
    now_str = datetime.utcnow().isoformat(timespec="seconds") + "Z"

    # مرحلة المسح وحساب/إعادة استخدام MD5
    for path in candidates:
        try:
            st = os.stat(path)
        except FileNotFoundError:
            continue

        size = st.st_size
        mtime = st.st_mtime
        family = classify_family(os.path.basename(path))

        # إعادة استخدام MD5 إذا كان مسجلاً بنفس الحجم والـ mtime
        cur.execute(
            "SELECT md5 FROM files WHERE path = ? AND size = ? AND mtime = ?",
            (path, size, mtime),
        )
        row = cur.fetchone()
        if row and row[0]:
            file_md5 = row[0]
        else:
            file_md5 = compute_md5(path)
            cur.execute(
                """
                INSERT INTO files(path, size, mtime, md5, family, status, cold_path, created_at)
                VALUES(?,?,?,?,?,?,?,?)
                ON CONFLICT(path) DO UPDATE SET
                    size      = excluded.size,
                    mtime     = excluded.mtime,
                    md5       = excluded.md5,
                    family    = excluded.family,
                    created_at= excluded.created_at,
                    status    = COALESCE(files.status, 'active')
                """,
                (path, size, mtime, file_md5, family, "active", None, now_str),
            )

        hash_map.setdefault(file_md5, []).append(path)
        processed += 1
        print_progress(processed, total, prefix="مسح الملفات: ")

    conn.commit()
    print()  # newline بعد شريط التقدم

    # مرحلة تحليل التكرار
    print(">> تحليل التكرار بالـ MD5...")
    dup_groups = {h: ps for h, ps in hash_map.items() if len(ps) > 1}
    print(f"عدد مجموعات التكرار: {len(dup_groups)}")

    moved = 0
    kept = 0

    for md5_hash, paths in dup_groups.items():
        canonical = choose_canonical(paths)
        kept += 1

        # تحديث حالة النسخة الأصلية
        cur.execute(
            "UPDATE files SET status = ? WHERE path = ?",
            ("canonical", canonical),
        )

        for p in paths:
            if p == canonical:
                continue

            # بناء مسار داخل cold_storage يحافظ على الهيكل النسبي
            rel = os.path.relpath(p, root)
            cold_path = os.path.join(cold_dir, rel)
            os.makedirs(os.path.dirname(cold_path), exist_ok=True)

            print(f"نقل مكرر -> {cold_path}")
            shutil.move(p, cold_path)
            moved += 1

            cur.execute(
                "UPDATE files SET status = ?, cold_path = ? WHERE path = ?",
                ("moved_duplicate", cold_path, p),
            )
            cur.execute(
                "INSERT INTO actions(path, action, reason, ts) VALUES (?,?,?,?)",
                (p, "MOVE_DUPLICATE", f"duplicate_of:{canonical}", now_str),
            )

    conn.commit()
    conn.close()

    print()
    print("=== ملخص Smart Cleanup ===")
    print(f"إجمالي الملفات الممسوحة      : {total}")
    print(f"عدد مجموعات التكرار          : {len(dup_groups)}")
    print(f"عدد النسخ الأصلية المحفوظة    : {kept}")
    print(f"عدد النسخ المكررة المنقولة     : {moved}")
    print("تم تحديث قاعدة بيانات الجرد والإجراءات (بدون حذف فعلي، فقط نقل إلى cold_storage).")

if __name__ == "__main__":
    main()
