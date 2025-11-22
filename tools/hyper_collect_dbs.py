#!/usr/bin/env python3
import os
import sys
import shutil
from multiprocessing import Pool
from datetime import datetime

BAR_WIDTH = 38

def term_width(default=120):
    try:
        import shutil as _sh
        return _sh.get_terminal_size((default, 20)).columns
    except Exception:
        return default

def print_progress(done, total, current_name):
    if total == 0:
        return
    import sys as _s
    percent = int(done * 100 / total)
    filled = int(percent * BAR_WIDTH / 100)
    bar = "#" * filled + "-" * (BAR_WIDTH - filled)
    name = os.path.basename(current_name) if current_name else ""
    line = f"[{bar}] {percent:3d}% ({done}/{total}) {name}"
    _s.stdout.write("\r" + line[:term_width()])
    _s.stdout.flush()
    if done == total:
        _s.stdout.write("\n")

def next_free_name(target_dir, base_name):
    name = base_name
    root, ext = os.path.splitext(base_name)
    counter = 2
    while os.path.exists(os.path.join(target_dir, name)):
        name = f"{root}.v{counter}{ext}"
        counter += 1
    return os.path.join(target_dir, name)

def worker(args):
    src, target_dir = args
    try:
        base = os.path.basename(src)
        dest = next_free_name(target_dir, base)
        shutil.copy2(src, dest)
        return (src, dest, None)
    except Exception as e:
        return (src, None, str(e))

def main():
    if len(sys.argv) < 4:
        print("Usage: hyper_collect_dbs.py ROOT TARGET FILE_LIST", file=sys.stderr)
        sys.exit(1)

    root = sys.argv[1]
    target = sys.argv[2]
    list_path = sys.argv[3]

    with open(list_path, "r", encoding="utf-8") as f:
        db_files = [line.rstrip("\n") for line in f if line.strip()]

    total = len(db_files)
    if total == 0:
        print("لا يوجد ملفات DB لتجميعها")
        return

    os.makedirs(target, exist_ok=True)

    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_path = os.path.join(root, f"db_collect_{ts}.log")

    print(f"📂 ROOT = {root}")
    print(f"🎯 TARGET = {target}")
    print(f"📄 DB LIST = {list_path}")
    print(f"🔢 TOTAL DBS = {total}")
    print(f"📝 LOG = {log_path}")
    print("🚀 بدء تجميع قواعد البيانات (6 أنوية)...")

    done = 0
    errors = []
    copied = []

    with Pool(processes=6) as pool:
        for src, dest, err in pool.imap_unordered(
            worker,
            [(p, target) for p in db_files],
            chunksize=8
        ):
            done += 1
            print_progress(done, total, src)
            if err is not None:
                errors.append((src, err))
            else:
                copied.append((src, dest))

    with open(log_path, "w", encoding="utf-8") as log:
        log.write("# HyperFFactory DB collect report\n")
        log.write(f"# ROOT: {root}\n")
        log.write(f"# TARGET: {target}\n")
        log.write(f"# TOTAL_DBS_FOUND: {total}\n")
        log.write(f"# TOTAL_DBS_COPIED: {len(copied)}\n")
        log.write(f"# ERRORS: {len(errors)}\n\n")

        log.write("## Copied DBs (src | dest)\n")
        for src, dest in copied:
            log.write(f"COPY|{src}|{dest}\n")

        if errors:
            log.write("\n## Errors\n")
            for src, err in errors:
                log.write(f"ERR|{src}|{err}\n")

    print(f"✅ عدد ملفات DB المنسوخة: {len(copied)}")
    print(f"📝 تقرير التجميع: {log_path}")
    if errors:
        print(f"⚠️ عدد الأخطاء أثناء النسخ: {len(errors)} (مذكورة في التقرير)")

if __name__ == "__main__":
    main()
