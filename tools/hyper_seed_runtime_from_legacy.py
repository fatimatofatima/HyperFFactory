#!/usr/bin/env python3
import os
import sqlite3
import json
from datetime import datetime
import argparse
from typing import Dict, Any, List


def now_utc() -> str:
    return datetime.utcnow().isoformat(timespec="seconds") + "Z"


def open_db(path: str, label: str) -> sqlite3.Connection:
    if not os.path.exists(path):
        raise RuntimeError(f"{label} DB not found: {path}")
    conn = sqlite3.connect(path)
    conn.row_factory = sqlite3.Row
    return conn


def ensure_meta_entity(identity_conn: sqlite3.Connection) -> int:
    """
    إنشاء/إرجاع كيان واحد يمثل hyper_meta.db داخل identity.entities
    بدون حذف أو تعديل أي كيان آخر.
    """
    cur = identity_conn.cursor()

    # نحاول إيجاد الكيان لو موجود مسبقًا
    cur.execute(
        "SELECT id FROM entities WHERE external_ref = ?",
        ("meta:hyper_meta.db",),
    )
    row = cur.fetchone()
    if row:
        return row["id"]

    now = now_utc()

    # نقرأ أسماء الأعمدة المتاحة في entities ديناميكيًا
    cur.execute("PRAGMA table_info(entities);")
    cols_info = cur.fetchall()
    col_names = {c["name"] for c in cols_info}

    # حقول أساسية
    fields = ["entity_type", "name", "status", "external_ref", "meta_json", "created_at", "updated_at"]
    values = [
        "system",
        "HyperMeta Inventory",
        "active",
        "meta:hyper_meta.db",
        json.dumps({"note": "auto-created from hyper_seed_runtime_from_legacy"}, ensure_ascii=False),
        now,
        now,
    ]

    # حقول اختيارية إذا كانت موجودة في السكيما
    if "external_id" in col_names:
        fields.append("external_id")
        values.append("hyper_meta")

    if "external_source" in col_names:
        fields.append("external_source")
        values.append("meta")

    if "metadata_json" in col_names:
        fields.append("metadata_json")
        values.append(json.dumps({}, ensure_ascii=False))

    sql = f"INSERT INTO entities ({', '.join(fields)}) VALUES ({', '.join(['?'] * len(fields))})"
    cur.execute(sql, values)
    identity_conn.commit()
    return cur.lastrowid


def fetch_db_files(meta_conn: sqlite3.Connection) -> List[sqlite3.Row]:
    cur = meta_conn.cursor()
    cur.execute("SELECT * FROM db_files;")
    rows = cur.fetchall()
    return rows


def build_role_summary(rows: List[sqlite3.Row]) -> Dict[str, Dict[str, float]]:
    summary: Dict[str, Dict[str, float]] = {}
    total_mb = 0.0
    total_files = 0

    for row in rows:
        # نتعامل مع الأعمدة ديناميكيًا
        keys = row.keys()
        role = row["role"] if "role" in keys else "unknown"
        size = row["size_mb"] if "size_mb" in keys and row["size_mb"] is not None else 0.0

        if role not in summary:
            summary[role] = {"count": 0, "total_mb": 0.0}

        summary[role]["count"] += 1
        summary[role]["total_mb"] += float(size)
        total_mb += float(size)
        total_files += 1

    summary["_meta"] = {
        "total_files": total_files,
        "total_mb": total_mb,
    }
    return summary


def already_seeded(memory_conn: sqlite3.Connection) -> bool:
    cur = memory_conn.cursor()
    try:
        cur.execute("SELECT COUNT(*) FROM events WHERE event_type = 'meta.db_file';")
        count = cur.fetchone()[0]
        return count > 0
    except sqlite3.OperationalError:
        # لو الجدول غير موجود أو الحقل مفقود (وهو غير متوقع هنا)
        return False


def seed_events(memory_conn: sqlite3.Connection, source_entity_id: int, rows: List[sqlite3.Row]) -> int:
    """
    إنشاء Event لكل صف في db_files داخل events.
    لا يوجد أي UPDATE/DELETE على البيانات القديمة.
    """
    if not rows:
        return 0

    cur = memory_conn.cursor()
    now = now_utc()
    inserted = 0

    for row in rows:
        data = {k: row[k] for k in row.keys()}
        payload = {
            "type": "meta.db_file",
            "meta_row": data,
        }
        cur.execute(
            """
            INSERT INTO events (
                timestamp,
                source_entity_id,
                event_type,
                severity,
                payload_json,
                correlation_id,
                created_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (
                now,
                source_entity_id,
                "meta.db_file",
                "info",
                json.dumps(payload, ensure_ascii=False),
                None,
                now,
            ),
        )
        inserted += 1

    memory_conn.commit()
    return inserted


def seed_snapshot(memory_conn: sqlite3.Connection, source_entity_id: int, summary: Dict[str, Any]) -> None:
    """
    إنشاء Snapshot تلخيصي في state_snapshots لحالة db_files حسب role.
    """
    cur = memory_conn.cursor()
    now = now_utc()
    snapshot_key = "meta.db_files.summary." + datetime.utcnow().strftime("%Y%m%d_%H%M%S")

    total_files = summary.get("_meta", {}).get("total_files", 0)
    total_mb = summary.get("_meta", {}).get("total_mb", 0.0)
    summary_text = f"Imported {total_files} db_files rows from hyper_meta.db (total ≈ {total_mb:.2f} MB)"

    state_json = json.dumps(summary, ensure_ascii=False)

    cur.execute(
        """
        INSERT INTO state_snapshots (
            snapshot_key,
            taken_at,
            source_entity_id,
            scope_type,
            scope_id,
            summary,
            state_json
        )
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """,
        (
            snapshot_key,
            now,
            source_entity_id,
            "meta",
            "hyper_meta.db",
            summary_text,
            state_json,
        ),
    )
    memory_conn.commit()


def main():
    parser = argparse.ArgumentParser(description="Seed runtime identity/memory from hyper_meta.db (read-only legacy).")
    parser.add_argument("--meta", required=True, help="Path to hyper_meta.db")
    parser.add_argument("--identity", required=True, help="Path to runtime identity.db")
    parser.add_argument("--memory", required=True, help="Path to runtime memory_core_YYYY.db")
    args = parser.parse_args()

    meta_db_path = os.path.abspath(args.meta)
    identity_db_path = os.path.abspath(args.identity)
    memory_db_path = os.path.abspath(args.memory)

    print("🧠 Seed من hyper_meta → runtime (identity + memory)")
    print(f"  META_DB     = {meta_db_path}")
    print(f"  IDENTITY_DB = {identity_db_path}")
    print(f"  MEMORY_DB   = {memory_db_path}")
    print("--------------------------------------------------")

    meta_conn = open_db(meta_db_path, "META")
    identity_conn = open_db(identity_db_path, "IDENTITY")
    memory_conn = open_db(memory_db_path, "MEMORY")

    # تأكيد أن الـ runtime نظيف (أو على الأقل لا نكرر نفس الـ events)
    if already_seeded(memory_conn):
        print("⚠️  تم العثور على events من نوع 'meta.db_file' بالفعل في memory_core – لن يتم التكرار.")
        return

    # 1) إنشاء/إحضار كيان hyper_meta في identity
    source_entity_id = ensure_meta_entity(identity_conn)
    print(f"✅ meta entity id = {source_entity_id}")

    # 2) جلب كل صفوف db_files من hyper_meta
    rows = fetch_db_files(meta_conn)
    print(f"🔎 db_files rows  = {len(rows)}")

    # 3) بناء summary حسب الدور
    summary = build_role_summary(rows)
    meta_info = summary.get("_meta", {})
    print(
        f"📊 summary       = total_files={meta_info.get('total_files', 0)}, "
        f"total_mb≈{meta_info.get('total_mb', 0.0):.2f}"
    )

    # 4) إدخال events
    inserted = seed_events(memory_conn, source_entity_id, rows)
    print(f"📝 events inserted= {inserted}")

    # 5) إدخال snapshot تلخيصي
    seed_snapshot(memory_conn, source_entity_id, summary)
    print("📦 snapshot       = meta.db_files.summary.* created")

    print("✅ انتهى الـ Seed بدون تعديل أي قاعدة بيانات قديمة (قراءة فقط من hyper_meta.db).")


if __name__ == "__main__":
    main()
