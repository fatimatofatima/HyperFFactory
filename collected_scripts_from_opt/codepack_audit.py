import os, re, csv, json, hashlib, sys
from pathlib import Path
from datetime import datetime

OUT_DIR = Path(sys.argv[1])
SRC_DIR = Path(sys.argv[2])

EXCLUDE_DIRS = {"node_modules",".git","build","dist","__pycache__",".venv","venv",".mypy_cache",".pytest_cache","bin","obj",".gradle",".idea",".vscode","Pods","DerivedData","target",".cache",".next",".nuxt"}
TEXT_EXTS = set(".py .js .ts .tsx .jsx .json .yaml .yml .toml .ini .cfg .env .sh .bat .ps1 .sql .md .rst .txt .csv .tsv .gradle .kts .xml .html .css .scss .cs .xaml .java .kt .c .h .cpp .hpp .proto".split())

def is_text_ext(p): return p.suffix.lower() in TEXT_EXTS
def is_probably_text(p):
    try:
        with open(p,"rb") as f: b=f.read(4096)
        if b"\x00" in b: return False
        if is_text_ext(p): return True
        return (sum(c<128 for c in b)/(len(b) or 1))>0.85
    except: return False
def count_lines(p):
    try:
        with open(p,"r",encoding="utf-8",errors="ignore") as f: return sum(1 for _ in f)
    except: return 0
def sha_sig(p):
    s=p.stat().st_size; h=hashlib.sha256(); lim=2*1024*1024
    if s<=lim:
        with open(p,"rb") as f:
            for ch in iter(lambda:f.read(1024*1024),b""): h.update(ch)
        return f"sha256:{h.hexdigest()}", s, False
    else:
        with open(p,"rb") as f: h.update(f.read(1024*1024))
        return f"sha256_head1mb:{h.hexdigest()}", s, True

project_markers={"python":["pyproject.toml","requirements.txt","setup.py","Pipfile"],"node":["package.json","yarn.lock","pnpm-lock.yaml","package-lock.json"],"dotnet":[".sln",".csproj",".fsproj",".vbproj"],"java":["pom.xml","build.gradle","build.gradle.kts","settings.gradle","gradlew"],"android":["AndroidManifest.xml","build.gradle","build.gradle.kts","gradlew"]}
def classify_root(d):
    k=[]
    for typ,marks in project_markers.items():
        for m in marks:
            if (d/m).exists(): k.append(typ); break
    return k

files_rows=[]; services_rows=[]; ports_rows=[]; imports_rows=[]; endpoints_rows=[]; tokens_rows=[]; projects_rows=[]
for root,dirs,files in os.walk(SRC_DIR):
    dirs[:]=[d for d in dirs if d not in EXCLUDE_DIRS]
    root_p=Path(root)
    kinds=classify_root(root_p)
    if kinds: projects_rows.append({"project_root":str(root_p.relative_to(SRC_DIR)),"types":",".join(sorted(set(kinds)))})
    for fn in files:
        fp=root_p/fn
        try: st=fp.stat()
        except FileNotFoundError: continue
        rel=str(fp.relative_to(SRC_DIR)); ext=fp.suffix.lower()
        text_like=is_probably_text(fp); lines=count_lines(fp) if text_like else None
        sig,size,partial=sha_sig(fp)
        files_rows.append({"path":rel,"size_bytes":size,"mtime":datetime.fromtimestamp(st.st_mtime).isoformat(),"ext":ext,"is_text_like":text_like,"lines":lines,"sig":sig,"sig_partial":partial})
        if ext==".service":
            try: txt=fp.read_text(encoding="utf-8",errors="ignore")
            except: txt=""
            import re as R
            desc=R.search(r"^Description\s*=\s*(.+)$",txt,R.M)
            execs=R.findall(r"^ExecStart\s*=\s*(.+)$",txt,R.M)
            user=R.search(r"^User\s*=\s*(.+)$",txt,R.M)
            services_rows.append({"unit_path":rel,"description":desc.group(1).strip() if desc else "","execstart":" | ".join([e.strip() for e in execs]) if execs else "","user":user.group(1).strip() if user else ""})
            for e in execs:
                for m in R.findall(r"(?:--port\s*=?\s*|[-\s]p\s*)(\d{2,5})",e): ports_rows.append({"source":"systemd","file":rel,"port":int(m),"line":"ExecStart"})
                for m in R.findall(r":(\d{2,5})(?:\b|/)",e): ports_rows.append({"source":"systemd","file":rel,"port":int(m),"line":"ExecStart"})
        if ext==".py":
            try: code=fp.read_text(encoding="utf-8",errors="ignore")
            except: code=""
            import re as R
            for m in R.finditer(r"^\s*(?:from\s+([A-Za-z0-9_\.]+)\s+import|import\s+([A-Za-z0-9_\.]+))",code,R.M):
                mod=m.group(1) or m.group(2); imports_rows.append({"file":rel,"module":mod})
            if re.search(r"\bFastAPI\s*\(",code): projects_rows.append({"project_root":str(root_p.relative_to(SRC_DIR)),"types":"fastapi"})
            if re.search(r"\bFlask\s*\(",code): projects_rows.append({"project_root":str(root_p.relative_to(SRC_DIR)),"types":"flask"})
            for m in R.finditer(r"@(?:app|router)\.(get|post|put|patch|delete)\(\s*([^\)]*)\)",code):
                method=m.group(1).upper(); args=m.group(2); pathm=re.search(r"['\"]([^'\"]+)['\"]",args); pathv=pathm.group(1) if pathm else ""
                endpoints_rows.append({"file":rel,"method":method,"path":pathv})
            for m in re.finditer(r"(?:uvicorn\.run|app\.run|uvicorn\s+)(?:.*?port\s*=?\s*)(\d{2,5})",code):
                ports_rows.append({"source":"code","file":rel,"port":int(m.group(1)),"line":"python"})
        if ext in [".env",".ini",".cfg",".yaml",".yml",".json",".toml",".py"] or text_like:
            try: txt=fp.read_text(encoding="utf-8",errors="ignore")
            except: txt=""
            for m in re.finditer(r"^\s*PORT\s*=\s*(\d{2,5})\s*$",txt,re.M): ports_rows.append({"source":"env","file":rel,"port":int(m.group(1)),"line":"PORT="})
            token_patterns={"bearer":r"bearer\s+[A-Za-z0-9\-\._~\+\/]+=*","jwt":r"eyJ[a-zA-Z0-9_\-]+?\.[a-zA-Z0-9_\-]+?\.[a-zA-Z0-9_\-]+","sk_like":r"(?:sk|rk|pk|ak|xai|ghp)_[A-Za-z0-9]{16,}","uuid":r"[a-fA-F0-9]{8}\-[a-fA-F0-9]{4}\-[a-fA-F0-9]{4}\-[a-fA-F0-9]{4}\-[a-fA-F0-9]{12}"}
            for t,pat in token_patterns.items():
                for mm in re.finditer(pat,txt,re.I):
                    s=mm.start(); e=mm.end(); start=max(s-12,0); end=min(e+12,len(txt))
                    snip=txt[start:end].replace("\n"," "); red=snip[:6]+"…REDACTED…"+snip[-6:]
                    tokens_rows.append({"file":rel,"type":t,"snippet":red})

def write_csv(rows, headers, name):
    p = OUT_DIR/name
    with open(p,"w",newline="",encoding="utf-8") as f:
        w=csv.DictWriter(f,fieldnames=headers); w.writeheader(); [w.writerow(r) for r in rows]
    return str(p)

# files
files_hdr=["path","size_bytes","mtime","ext","is_text_like","lines","sig","sig_partial"]
write_csv(files_rows, files_hdr, "files.csv")

# projects dedup
seen=set(); proj=[]
for r in projects_rows:
    k=(r["project_root"],r["types"])
    if k in seen: continue
    seen.add(k); proj.append(r)
write_csv(proj, ["project_root","types"], "projects.csv")

write_csv(services_rows, ["unit_path","description","execstart","user"], "services.csv")

# ports dedup
seen=set(); pr=[]
for r in ports_rows:
    k=(r.get("source"),r.get("file"),r.get("port"),r.get("line"))
    if k in seen: continue
    seen.add(k); pr.append(r)
write_csv(pr, ["source","file","port","line"], "ports.csv")

# imports
seen=set(); im=[]
for r in imports_rows:
    k=(r["file"],r["module"])
    if k in seen: continue
    seen.add(k); im.append(r)
write_csv(im, ["file","module"], "imports.csv")

# endpoints
seen=set(); ep=[]
for r in endpoints_rows:
    k=(r["file"],r["method"],r["path"])
    if k in seen: continue
    seen.add(k); ep.append(r)
write_csv(ep, ["file","method","path"], "endpoints.csv")

# tokens
seen=set(); tk=[]
for r in tokens_rows:
    k=(r["file"],r["type"],r["snippet"])
    if k in seen: continue
    seen.add(k); tk.append(r)
write_csv(tk, ["file","type","snippet"], "tokens.csv")

# duplicates by sig
from collections import defaultdict
g=defaultdict(list)
for r in files_rows: g[r["sig"]].append(r)
dups=[]
for sig,lst in g.items():
    if len(lst)>1: dups+=sorted(lst,key=lambda x:(x["size_bytes"],x["path"]))
write_csv(dups, files_hdr, "duplicates.csv")

# tree
def make_tree(root,max_depth=3):
    lines=[]
    def rec(p,d):
        if d>max_depth: return
        try: ents=sorted(p.iterdir(), key=lambda x:(x.is_file(),x.name.lower()))
        except: return
        for e in ents:
            if e.name in EXCLUDE_DIRS: continue
            lines.append("  "*d+("📁 " if e.is_dir() else "📄 ")+e.name)
            if e.is_dir(): rec(e,d+1)
    rec(SRC_DIR,0); return "\n".join(lines)
(OUT_DIR/"tree.txt").write_text(make_tree(SRC_DIR,3),encoding="utf-8")

summary={"generated_at":datetime.now().isoformat(),"src_root":str(SRC_DIR),"reports_dir":str(OUT_DIR),
         "counts":{"files":len(files_rows),"projects":len({r["project_root"] for r in proj}),
                   "services":len(services_rows),"ports":len(pr),"imports":len(im),
                   "endpoints":len(ep),"tokens":len(tk),"duplicates":len(dups)}}
(OUT_DIR/"summary.json").write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding="utf-8")
print(json.dumps(summary,ensure_ascii=False))
