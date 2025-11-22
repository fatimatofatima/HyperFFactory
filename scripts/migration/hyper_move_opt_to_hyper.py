#!/usr/bin/env python3
import os
import shutil
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime

BASE_SRC = "/opt"
BASE_DST = "/root/HyperFFactory/imported/opt"
LOG_DIR  = "/root/HyperFFactory/docs"

EXCLUDES = {
    "ffactory",          # المشروع اللي ممنوع لمسه
    "ffactory_core",
    "ffactory-old",
}

def list_items():
    items = []
    for name in sorted(os.listdir(BASE_SRC)):
        if name in (".", ".."):
            continue
        if name in EXCLUDES:
            continue
        src = os.path.join(BASE_SRC, name)
        # نتجاهل لو مش موجود (حالات نادرة)
        if not os.path.exists(src):
            continue
        dst = os.path.join(BASE_DST, name)
        items.append((src, dst))
    return items

def move_item(job):
    src, dst = job
    try:
        # لو الهدف موجود، ما نحاولش نكسره
        if os.path.exists(dst):
            return (src, dst, "SKIP_EXISTS")
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.move(src, dst)
        return (src, dst, "OK")
    except Exception as e:
        return (src, dst, f"ERROR: {e}")

def main():
    os.makedirs(BASE_DST, exist_ok=True)
    os.makedirs(LOG_DIR, exist_ok=True)

    jobs = list_items()
    total = len(jobs)

    if total == 0:
        print("لا يوجد أي عناصر لنقلها من /opt (بعد استبعاد ffactory*)")
        return

    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_path = os.path.join(LOG_DIR, f"opt_move_log_{ts}.txt")

    print(f"سيتم نقل {total} عنصراً من {BASE_SRC} إلى {BASE_DST}")
    print(f"سيتم استخدام 6 Threads مع شريط تقدم بسيط")
    print(f"ملف اللوج: {log_path}")
    print("-" * 60)

    # تأكيد بسيط قبل التنفيذ
    answer = input("تأكيد النقل المباشر (move)؟ اكتب YES بالحروف الكبيرة: ").strip()
    if answer != "YES":
        print("تم الإلغاء من المستخدم.")
        return

    moved = 0
    errors = 0
    skipped = 0

    start_time = time.time()

    with open(log_path, "w", encoding="utf-8") as log:
        log.write(f"OPT MOVE LOG {ts}\n")
        log.write(f"SRC: {BASE_SRC}\nDST: {BASE_DST}\n\n")

        with ThreadPoolExecutor(max_workers=6) as pool:
            futures = {pool.submit(move_item, job): job for job in jobs}
            for i, fut in enumerate(as_completed(futures), start=1):
                src, dst, status = fut.result()
                if status == "OK":
                    moved += 1
                elif status == "SKIP_EXISTS":
                    skipped += 1
                else:
                    errors += 1

                # شريط تقدم بسيط
                ratio = i / total
                bar_len = 40
                filled = int(bar_len * ratio)
                bar = "#" * filled + "-" * (bar_len - filled)
                sys.stdout.write(f"\r[{bar}] {i}/{total} moved={moved} skipped={skipped} errors={errors}")
                sys.stdout.flush()

                log.write(f"{status}\t{src}\t{dst}\n")

    elapsed = time.time() - start_time
    sys.stdout.write("\n")
    print(f"اكتمل النقل في {elapsed:.1f} ثانية.")
    print(f"تم نقل: {moved}, تم تخطي: {skipped}, أخطاء: {errors}")
    print(f"تفاصيل كاملة في: {log_path}")

if __name__ == "__main__":
    main()
