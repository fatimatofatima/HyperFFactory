import os
import hashlib
from concurrent.futures import ProcessPoolExecutor, as_completed
from datetime import datetime
from typing import List, Dict

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

SEARCH_ROOTS = [
    "/root",
    "/opt",
    "/srv",
]

EXCLUDE_DIR_NAMES = {
    "proc", "sys", "dev", "run", "tmp",
    "snap", "flatpak", "docker",
    "venv", ".venv", "__pycache__", "node_modules",
    ".git", ".idea", ".vscode", ".cache",
    "site-packages", "dist-packages"
}

EXCLUDE_PATH_SUBSTR = [
    "/usr/",
    "/lib/",
    "/var/lib/docker",
    "/var/snap",
]

def is_excluded_dir(path: str) -> bool:
    parts = path.split(os.sep)
    for p in parts:
        if p in EXCLUDE_DIR_NAMES:
            return True
    for s in EXCLUDE_PATH_SUBSTR:
        if s in path:
            return True
    return False

def iter_candidate_files() -> List[str]:
    exts = {".sh", ".py"}
    files: List[str] = []
    for root in SEARCH_ROOTS:
        if not os.path.isdir(root):
            continue
        for dirpath, dirnames, filenames in os.walk(root):
            if is_excluded_dir(dirpath):
                dirnames[:] = []
                continue
            dirnames[:] = [d for d in dirnames if d not in EXCLUDE_DIR_NAMES]
            for name in filenames:
                ext = os.path.splitext(name)[1].lower()
                if ext in exts:
                    full = os.path.join(dirpath, name)
                    skip = False
                    for s in EXCLUDE_PATH_SUBSTR:
                        if s in full:
                            skip = True
                            break
                    if not skip:
                        files.append(full)
    return files

def classify_family(path: str) -> str:
    lower = path.lower()
    if "hyper-factory" in lower:
        return "hyper_factory"
    if "smartfriend-complete-system" in lower:
        return "smartfriend_complete_system"
    if "smartfriend-suite" in lower:
        return "smartfriend_suite"
    if "ffactory" in lower or "factory" in lower:
        return "ffactory"
    if "/opt/" in lower:
        return "opt_other"
    if "/srv/" in lower:
        return "srv_other"
    if "/root/" in lower:
        return "root_other"
    return "other"

def top_folder_under_root(path: str) -> str:
    for base in SEARCH_ROOTS:
        if path.startswith(base + os.sep):
            rel = os.path.relpath(path, base)
            parts = rel.split(os.sep)
            return parts[0] if parts else "(root)"
    return "(unknown)"

def hash_and_meta(path: str) -> Dict:
    try:
        st = os.stat(path)
    except FileNotFoundError:
        return None

    size = st.st_size
    mtime = st.st_mtime
    ext = os.path.splitext(path)[1].lower()

    h = hashlib.sha256()
    try:
        with open(path, "rb") as f:
            for chunk in iter(lambda: f.read(1024 * 1024), b""):
                h.update(chunk)
    except Exception:
        return None

    sha256 = h.hexdigest()
    family = classify_family(path)
    top = top_folder_under_root(path)

    first_line = ""
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as f:
            first_line = f.readline().strip()
    except Exception:
        first_line = ""

    return {
        "path": path,
        "sha256": sha256,
        "size": size,
        "mtime": mtime,
        "ext": ext,
        "family": family,
        "top_folder": top,
        "first_line": first_line,
    }

def main():
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    report_dir = os.path.join(BASE_DIR, "reports", "code_inventory")
    os.makedirs(report_dir, exist_ok=True)

    inventory_file = os.path.join(report_dir, f"sh_py_inventory_{ts}.tsv")
    summary_file = os.path.join(report_dir, f"sh_py_summary_{ts}.tsv")

    print("== SH/PY Inventory Collector ==")
    print("Search roots:")
    for r in SEARCH_ROOTS:
        print("  -", r)
    print("Report dir :", report_dir)
    print("Timestamp  :", ts)
    print("Workers    : 6")
    print()

    files = iter_candidate_files()
    total = len(files)
    print(f"Found {total} candidate files after filters.")
    if not total:
        print("INVENTORY_FILE=" + inventory_file)
        print("SUMMARY_FILE=" + summary_file)
        return

    records = []
    processed = 0
    step = max(1, total // 50)

    with ProcessPoolExecutor(max_workers=6) as ex:
        futures = {ex.submit(hash_and_meta, p): p for p in files}
        for fut in as_completed(futures):
            rec = fut.result()
            processed += 1
            if rec is not None:
                records.append(rec)
            if processed % step == 0 or processed == total:
                pct = processed * 100.0 / total
                print(f"[PROGRESS] {processed}/{total} ({pct:5.1f}%)")

    records.sort(key=lambda r: (r["family"], r["top_folder"], r["path"]))

    with open(inventory_file, "w", encoding="utf-8") as f:
        f.write("sha256\tsize_bytes\tmtime_iso\text\tfamily\ttop_folder\tpath\tfirst_line\n")
        for r in records:
            mtime_iso = datetime.fromtimestamp(r["mtime"]).isoformat(sep=" ", timespec="seconds")
            f.write(
                f"{r['sha256']}\t"
                f"{r['size']}\t"
                f"{mtime_iso}\t"
                f"{r['ext']}\t"
                f"{r['family']}\t"
                f"{r['top_folder']}\t"
                f"{r['path']}\t"
                f"{r['first_line'].replace('\t',' ')[:200]}\n"
            )

    from collections import Counter, defaultdict
    family_counts = Counter(r["family"] for r in records)
    ext_counts = Counter(r["ext"] for r in records)
    folder_counts = defaultdict(int)
    for r in records:
        key = (r["family"], r["top_folder"])
        folder_counts[key] += 1

    with open(summary_file, "w", encoding="utf-8") as s:
        s.write("# family\ttop_folder\tcount\n")
        for (fam, top), cnt in sorted(folder_counts.items(), key=lambda x: (-x[1], x[0][0], x[0][1])):
            s.write(f"{fam}\t{top}\t{cnt}\n")

        s.write("\n# family_totals\n")
        for fam, cnt in family_counts.most_common():
            s.write(f"{fam}\t{cnt}\n")

        s.write("\n# ext_totals\n")
        for ext, cnt in ext_counts.most_common():
            s.write(f"{ext}\t{cnt}\n")

    print()
    print("Inventory records:", len(records))
    print("INVENTORY_FILE=" + inventory_file)
    print("SUMMARY_FILE=" + summary_file)

if __name__ == "__main__":
    main()
