#!/usr/bin/env python3
import os, sys, csv, hashlib, stat, json
from pathlib import Path
from datetime import datetime

def is_probably_text(path, blocksize=4096):
    try:
        with open(path, "rb") as f:
            chunk = f.read(blocksize)
        if b"\x00" in chunk:
            return False
        text_chars = b"\n\r\t\f\b"
        printable = sum(1 for b in chunk if 32 <= b <= 126 or b in text_chars)
        if not chunk:
            return True
        return printable / len(chunk) >= 0.7
    except Exception:
        return False

def count_lines(path):
    try:
        with open(path, "rb") as f:
            return sum(1 for _ in f)
    except Exception:
        return None

def sha_sig(path, limit=2*1024*1024):
    try:
        st = path.stat()
    except FileNotFoundError:
        return None, None, None
    size = st.st_size
    h = hashlib.sha256()
    partial = False
    try:
        with open(path, "rb") as f:
            if size <= limit:
                for chunk in iter(lambda: f.read(1024*1024), b""):
                    if not chunk:
                        break
                    h.update(chunk)
            else:
                partial = True
                remaining = limit
                while remaining > 0:
                    chunk = f.read(min(1024*1024, remaining))
                    if not chunk:
                        break
                    h.update(chunk)
                    remaining -= len(chunk)
    except Exception:
        return None, size, None
    tag = "sha256_head2mb" if partial else "sha256"
    return f"{tag}:{h.hexdigest()}", size, partial

PROJECT_MARKERS = {
    "python": ["pyproject.toml", "requirements.txt", "setup.py"],
    "node": ["package.json"],
    "dotnet": [".sln", ".csproj"],
    "android": ["AndroidManifest.xml", "build.gradle", "build.gradle.kts", "gradlew"],
}

def detect_project_types(dir_path: Path):
    kinds = []
    for kind, markers in PROJECT_MARKERS.items():
        for m in markers:
            if (dir_path / m).exists():
                kinds.append(kind)
                break
    return kinds

def parse_service_file(path: Path):
    try:
        txt = path.read_text(encoding="utf-8", errors="ignore")
    except Exception:
        return None, None
    desc = None
    exec_start = None
    for line in txt.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        low = line.lower()
        if low.startswith("description="):
            desc = line.split("=", 1)[1].strip()
        elif low.startswith("execstart="):
            exec_start = line.split("=", 1)[1].strip()
    return desc, exec_start

def walk_roots(roots, out_dir: Path):
    files_csv = out_dir / "audit_files.csv"
    projects_csv = out_dir / "audit_projects.csv"
    services_csv = out_dir / "audit_services.csv"
    summary_json = out_dir / "audit_summary.json"

    files_f = files_csv.open("w", newline="", encoding="utf-8")
    projects_f = projects_csv.open("w", newline="", encoding="utf-8")
    services_f = services_csv.open("w", newline="", encoding="utf-8")

    files_writer = csv.writer(files_f)
    files_writer.writerow([
        "root",
        "rel_path",
        "size_bytes",
        "mtime_iso",
        "mode",
        "is_dir",
        "is_symlink",
        "is_text",
        "ext",
        "lines",
        "sig",
        "sig_partial",
    ])

    projects_writer = csv.writer(projects_f)
    projects_writer.writerow([
        "root",
        "project_root_rel",
        "types",
    ])

    services_writer = csv.writer(services_f)
    services_writer.writerow([
        "root",
        "service_path_rel",
        "description",
        "exec_start",
    ])

    stats = {
        "total_files": 0,
        "total_dirs": 0,
        "total_size_bytes": 0,
        "by_ext": {},
    }

    seen_projects = set()

    for root in roots:
        root_path = Path(root).resolve()
        if not root_path.exists():
            continue

        for dirpath, dirnames, filenames in os.walk(root_path):
            dirpath_p = Path(dirpath)
            rel_dir = dirpath_p.relative_to(root_path)

            # رصد جذور المشاريع
            kinds = detect_project_types(dirpath_p)
            if kinds:
                key = (str(root_path), str(rel_dir))
                if key not in seen_projects:
                    seen_projects.add(key)
                    projects_writer.writerow([
                        str(root_path),
                        str(rel_dir),
                        ",".join(sorted(set(kinds))),
                    ])

            # تسجيل المجلد نفسه
            try:
                st = dirpath_p.lstat()
            except FileNotFoundError:
                continue
            mtime_iso = datetime.fromtimestamp(st.st_mtime).isoformat()
            mode_str = oct(st.st_mode & 0o777)
            files_writer.writerow([
                str(root_path),
                str(rel_dir) + "/",
                st.st_size,
                mtime_iso,
                mode_str,
                True,
                stat.S_ISLNK(st.st_mode),
                "",
                "",
                None,
                None,
                None,
            ])
            stats["total_dirs"] += 1

            # الملفات داخل المجلد
            for fn in filenames:
                full = dirpath_p / fn
                try:
                    st = full.lstat()
                except FileNotFoundError:
                    continue
                is_link = stat.S_ISLNK(st.st_mode)
                is_dir = stat.S_ISDIR(st.st_mode)
                mode_str = oct(st.st_mode & 0o777)
                rel = full.relative_to(root_path)
                mtime_iso = datetime.fromtimestamp(st.st_mtime).isoformat()
                ext = full.suffix.lower()

                if is_dir:
                    is_text = False
                    lines = None
                    sig = None
                    partial = None
                    size = st.st_size
                else:
                    is_text = is_probably_text(full)
                    lines = count_lines(full) if is_text else None
                    sig, size, partial = sha_sig(full)
                    if size is not None:
                        stats["total_size_bytes"] += size

                files_writer.writerow([
                    str(root_path),
                    str(rel),
                    st.st_size,
                    mtime_iso,
                    mode_str,
                    is_dir,
                    is_link,
                    is_text,
                    ext,
                    lines,
                    sig,
                    partial,
                ])

                stats["total_files"] += 1
                if ext:
                    stats["by_ext"].setdefault(ext, 0)
                    stats["by_ext"][ext] += 1

                # تحليل ملفات systemd
                if ext == ".service" and not is_dir:
                    desc, exec_start = parse_service_file(full)
                    services_writer.writerow([
                        str(root_path),
                        str(rel),
                        desc or "",
                        exec_start or "",
                    ])

    files_f.close()
    projects_f.close()
    services_f.close()
    summary_json.write_text(json.dumps(stats, indent=2), encoding="utf-8")

def main():
    if len(sys.argv) < 3:
        print("Usage: sf_deep_audit.py OUT_DIR ROOT1 [ROOT2 ...]", file=sys.stderr)
        sys.exit(1)
    out_dir = Path(sys.argv[1]).expanduser().resolve()
    roots = [Path(r).expanduser().resolve() for r in sys.argv[2:]]
    out_dir.mkdir(parents=True, exist_ok=True)
    walk_roots(roots, out_dir)

if __name__ == "__main__":
    main()
