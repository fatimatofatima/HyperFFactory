#!/usr/bin/env python3
import os
import sys
import hashlib
from multiprocessing import Pool
from datetime import datetime

BAR_WIDTH = 38

def sha256_of_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def worker(path):
    try:
        digest = sha256_of_file(path)
        return (path, digest, None)
    except Exception as e:
        return (path, None, str(e))

def print_progress(done, total, current_name):
    if total == 0:
        return
    percent = int(done * 100 / total)
    filled = int(percent * BAR_WIDTH / 100)
    bar = "#" * filled + "-" * (BAR_WIDTH - filled)
    name = os.path.basename(current_name) if current_name else ""
    line = f"[{bar}] {percent:3d}% ({done}/{total}) {name}"
    sys.stdout.write("\r" + line[:term_width()])
    sys.stdout.flush()
    if done == total:
        sys.stdout.write("\n")

def term_width(default=120):
    try:
        import shutil
        return shutil.get_terminal_size((default, 20)).columns
    except Exception:
        return default

def main():
    if len(sys.argv) < 3:
        print("Usage: hyper_dedupe_by_hash.py ROOT FILE_LIST", file=sys.stderr)
        sys.exit(1)

    root = sys.argv[1]
    list_path = sys.argv[2]

    with open(list_path, "r", encoding="utf-8") as f:
        files = [line.rstrip("\n") for line in f if line.strip()]

    total = len(files)
    if total == 0:
        print("لا يوجد ملفات لمعالجتها")
        return

    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_path = os.path.join(root, f"dedupe_deleted_{ts}.log")

    print(f"📂 ROOT = {root}")
    print(f"📄 FILE LIST = {list_path}")
    print(f"🔢 TOTAL FILES = {total}")
    print(f"📝 LOG = {log_path}")
    print("🚀 بدء حساب الهاشات (6 أنوية)...")

    by_hash = {}
    errors = []
    done = 0

    with Pool(processes=6) as pool:
        for path, digest, err in pool.imap_unordered(worker, files, chunksize=16):
            done += 1
            print_progress(done, total, path)
            if err is not None:
                errors.append((path, err))
                continue
            by_hash.setdefault(digest, []).append(path)

    print("✅ انتهى حساب الهاشات، بدء مرحلة الحذف...")

    deleted = []
    bytes_freed = 0

    for digest, paths in by_hash.items():
        if len(paths) <= 1:
            continue
        # احتفظ بأول مسار، واحذف الباقي
        keep = paths[0]
        for p in paths[1:]:
            try:
                size = os.path.getsize(p)
            except OSError:
                size = 0
            try:
                os.remove(p)
                deleted.append((p, keep, digest, size))
                bytes_freed += size
            except Exception as e:
                errors.append((p, f"delete-failed: {e}"))

    with open(log_path, "w", encoding="utf-8") as log:
        log.write("# HyperFFactory dedupe-by-hash report\n")
        log.write(f"# ROOT: {root}\n")
        log.write(f"# TOTAL_FILES_SCANNED: {total}\n")
        log.write(f"# UNIQUE_HASHES: {len(by_hash)}\n")
        log.write(f"# DUPLICATE_FILES_DELETED: {len(deleted)}\n")
        log.write(f"# BYTES_FREED: {bytes_freed}\n\n")

        log.write("## Deleted duplicates (path | kept_path | hash | bytes_freed)\n")
        for p, keep, digest, size in deleted:
            log.write(f"DEL|{p}|KEEP|{keep}|HASH|{digest}|SIZE|{size}\n")

        if errors:
            log.write("\n## Errors\n")
            for p, err in errors:
                log.write(f"ERR|{p}|{err}\n")

    print(f"🧹 عدد الملفات المحذوفة (مكررة): {len(deleted)}")
    print(f"📦 المساحة المُسترجعة (تقريبًا): {bytes_freed} bytes")
    print(f"📝 تقرير الحذف: {log_path}")
    if errors:
        print(f"⚠️ عدد الأخطاء أثناء الفحص/الحذف: {len(errors)} (مذكورة في التقرير)")

if __name__ == "__main__":
    main()
