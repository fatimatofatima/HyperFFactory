#!/usr/bin/env python3
import os
import sys
import sqlite3
import json
from datetime import datetime
from collections import defaultdict

ROOT = "/root/HyperFFactory"
DB_DIR = os.path.join(ROOT, "all_legacy_dbs")

os.makedirs(DB_DIR, exist_ok=True)

def is_sqlite_db(path: str) -> bool:
    """تأكد سريع أن الملف SQLite فعلاً."""
    try:
        with open(path, "rb") as f:
            header = f.read(16)
        return header.startswith(b"SQLite format 3")
    except Exception:
        return False

def classify_role(fname, tables):
    """تخمين دور القاعدة حسب الاسم والجداول."""
    name = fname.lower()
    tset = {t.lower() for t in tables}

    # ذاكرة
    if any(k in name for k in ["memory", "smart_memory", "active_memory", "unified_memory"]):
        return "memory_core"
    if any(t in tset for t in ["ai_memory", "memory", "smart_memory", "active_memory"]):
        return "memory_core"

    # هوية
    if "identity" in name or "id_" in name:
        return "identity"
    if any(t in tset for t in ["users", "profiles", "identities", "accounts"]):
        return "identity"

    # مركز المعرفة / unified
    if "smartfriend_unified" in name or "unified" in name:
        return "knowledge_hub"
    if any(t in tset for t in ["kb_items", "kb_entries", "knowledge", "facts"]):
        return "knowledge_hub"

    # neural / أنماط
    if "neural" in name or "pattern" in name or "core" in name:
        return "neural_patterns"

    # مصنع / factory
    if "factory" in name or "ffactory" in name:
        return "factory_ops"

    # data_home
    if "data_home" in name:
        return "data_home"

    # smartfrind / smartfriend عامة
    if "smartfrind" in name or "smartfriend" in name:
        return "smartfriend_legacy"

    # cma / meta
    if "cma" in name or "meta" in name:
        return "meta_control"

    return "other"

def scan_db(path):
    info = {
        "path": path,
        "name": os.path.basename(path),
        "size_bytes": os.path.getsize(path),
        "tables": [],
        "table_count": 0,
        "row_counts": {},
        "role": "",
        "error": ""
    }

    if not is_sqlite_db(path):
        info["error"] = "NOT_SQLITE"
        return info

    try:
        conn = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
        cur = conn.cursor()

        cur.execute("SELECT name FROM sqlite_master WHERE type='table'")
        tables = [r[0] for r in cur.fetchall()]
        info["tables"] = tables
        info["table_count"] = len(tables)

        row_counts = {}
        for t in tables[:25]:
            try:
                cur.execute(f"SELECT COUNT(*) FROM '{t}'")
                row_counts[t] = cur.fetchone()[0]
            except Exception as e:
                row_counts[t] = f"ERR:{e.__class__.__name__}"

        info["row_counts"] = row_counts
        info["role"] = classify_role(info["name"], tables)

        conn.close()
    except Exception as e:
        info["error"] = f"{e.__class__.__name__}: {e}"

    return info

def main():
    if not os.path.isdir(DB_DIR):
        print(f"لا يوجد مجلد قواعد بيانات: {DB_DIR}")
        sys.exit(1)

    db_files = []
    for entry in sorted(os.listdir(DB_DIR)):
        p = os.path.join(DB_DIR, entry)
        if os.path.isfile(p):
            db_files.append(p)

    if not db_files:
        print(f"لا توجد ملفات في {DB_DIR}")
        sys.exit(0)

    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    tsv_path = os.path.join(ROOT, f"db_inventory_{ts}.tsv")
    summary_path = os.path.join(ROOT, f"db_inventory_summary_{ts}.txt")

    print(f"عدد الملفات المرشحة للفحص: {len(db_files)}")
    print(f"ملف التفاصيل: {tsv_path}")
    print(f"ملف الملخص: {summary_path}")

    records = []

    for idx, path in enumerate(db_files, start=1):
        rel = os.path.relpath(path, ROOT)
        print(f"[{idx}/{len(db_files)}] فحص {rel} ...")
        info = scan_db(path)
        records.append(info)

    # كتابة TSV
    with open(tsv_path, "w", encoding="utf-8") as f:
        header = [
            "name",
            "role",
            "size_mb",
            "table_count",
            "tables",
            "row_counts_json",
            "error",
            "path"
        ]
        f.write("\t".join(header) + "\n")
        for r in records:
            size_mb = r["size_bytes"] / (1024 * 1024)
            row_counts_json = json.dumps(r["row_counts"], ensure_ascii=False)
            line = [
                r["name"],
                r["role"] or "",
                f"{size_mb:.3f}",
                str(r["table_count"]),
                ",".join(r["tables"]),
                row_counts_json,
                r["error"],
                r["path"],
            ]
            f.write("\t".join(line) + "\n")

    # بناء ملخص حسب الدور
    by_role = defaultdict(list)
    for r in records:
        key = r["role"] or "unknown"
        by_role[key].append(r)

    for role, lst in by_role.items():
        lst.sort(key=lambda x: x["size_bytes"], reverse=True)

    total_size = sum(r["size_bytes"] for r in records)
    total_mb = total_size / (1024 * 1024)

    with open(summary_path, "w", encoding="utf-8") as f:
        f.write("=== HyperFFactory DB Inventory ===\n")
        f.write(f"ROOT: {ROOT}\n")
        f.write(f"DB_DIR: {DB_DIR}\n")
        f.write(f"Total DB files: {len(records)}\n")
        f.write(f"Total size (MB): {total_mb:.2f}\n\n")

        errors = [r for r in records if r["error"]]
        f.write(f"=== Errors / Non-SQLite ({len(errors)}) ===\n")
        for r in errors[:50]:
            f.write(f"- {r['name']} :: {r['error']}\n")
        if len(errors) > 50:
            f.write(f"... ({len(errors)-50} more)\n")
        f.write("\n")

        f.write("=== Roles Overview ===\n")
        for role, lst in sorted(by_role.items(), key=lambda x: x[0]):
            size_role = sum(r["size_bytes"] for r in lst) / (1024 * 1024)
            f.write(f"[{role}] count={len(lst)}, size_mb={size_role:.2f}\n")
        f.write("\n")

        f.write("=== Top DBs per Role (by size) ===\n")
        for role, lst in sorted(by_role.items(), key=lambda x: x[0]):
            f.write(f"\n## Role: {role}\n")
            for r in lst[:10]:
                size_mb = r["size_bytes"] / (1024 * 1024)
                rel = os.path.relpath(r["path"], ROOT)
                f.write(f"- {r['name']} | {size_mb:.2f} MB | tables={r['table_count']} | path={rel}\n")

    print("انتهى الفحص. راجع ملفي:")
    print(f"  {tsv_path}")
    print(f"  {summary_path}")

if __name__ == "__main__":
    main()
