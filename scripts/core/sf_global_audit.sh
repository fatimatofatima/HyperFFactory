#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

APP_ROOT="/opt/smartfriend-suite"
REVIEW_ROOT="/root/smartfriend_review"
REPORT_ROOT="/root/sf_global_reports"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="${REPORT_ROOT}/global_audit_${TS}"
LOG="${OUT}/sf_global_audit_${TS}.log"

mkdir -p "$OUT"

teeout(){ tee -a "$LOG" >/dev/null; }
sec(){
  echo | teeout
  echo "============================================================" | teeout
  echo "== $1" | teeout
  echo "============================================================" | teeout
}
run(){
  echo "\$ $*" | teeout
  eval "$@" 2>&1 | teeout
}

echo "[*] SmartFriend – Global Audit @ ${TS}" | teeout

# =========================
# 1) System Snapshot
# =========================
sec "System Snapshot"
if command -v hostnamectl >/dev/null 2>&1; then
  run "hostnamectl"
fi
run "uname -a"
run "uptime"
run "date"

sec "CPU / Memory / Disk"
run "lscpu | egrep 'Model name|CPU\\(s\\)' || true"
run "free -h"
run "df -h /"
run "df -hi /"

sec "Top Processes (CPU / MEM)"
run "ps aux --sort=-%cpu | head -10"
run "ps aux --sort=-%mem | head -10"

# =========================
# 2) Network / Ports
# =========================
sec "Network / Listening Ports"
if command -v ip >/dev/null 2>&1; then
  run "ip -4 addr show"
fi
echo "== All listening ports (head) ==" | teeout
run "ss -tlnp | head -40"
echo "== SmartFriend-related ports ==" | teeout
run "ss -tlnp | egrep '(:8211|:8214|:8220|:8170|:8000|:9191|:5432|:6379)' || echo 'no critical ports matched'"

# =========================
# 3) /opt layout + SmartFriend folders
# =========================
sec "/opt Layout – High Level"

analyze_directory() {
    local dir="$1"
    local depth="${2:-0}"

    if [ ! -d "$dir" ]; then
        return
    fi

    local indent=""
    for _ in $(seq 1 "$depth"); do
        indent="${indent}  "
    done

    local file_count
    local dir_count
    local total_size

    file_count=$(find "$dir" -maxdepth 1 -type f 2>/dev/null | wc -l)
    dir_count=$(find "$dir" -maxdepth 1 -type d 2>/dev/null | wc -l)
    total_size=$(du -sh "$dir" 2>/dev/null | cut -f1)

    printf "%s%s\n" "$indent" "$(basename "$dir")"
    printf "%s    %d ملف، %d مجلد، الحجم: %s\n" "$indent" "$((file_count - 1))" "$((dir_count - 1))" "$total_size"

    local important_files
    important_files=$(find "$dir" -maxdepth 1 -type f \( -name "*.sh" -o -name "*.py" -o -name "*.md" -o -name "*.json" \) 2>/dev/null | head -5)
    if [ -n "$important_files" ]; then
        printf "%s    ملفات مهمة:\n" "$indent"
        echo "$important_files" | while read -r file; do
            local size
            size=$(du -h "$file" 2>/dev/null | cut -f1)
            printf "%s     - %s (%s)\n" "$indent" "$(basename "$file")" "$size"
        done
    fi

    if [ "$depth" -lt 1 ]; then
        find "$dir" -maxdepth 1 -type d ! -path "$dir" 2>/dev/null | sort | while read -r subdir; do
            analyze_directory "$subdir" "$((depth + 1))"
        done
    fi

    echo ""
}

if [ -d /opt ]; then
  find /opt -maxdepth 1 -type d ! -path "/opt" 2>/dev/null | sort | while read -r main_dir; do
    analyze_directory "$main_dir" 0 | teeout
  done
else
  echo "[WARN] /opt not found" | teeout
fi

sec "SmartFriend-related Directories Under /opt"
SMART_PATTERNS="*smart* *friend* *frind* *frined* *ffactory* *deepseek* *brain* *core* *fusion* *miracle*"
if [ -d /opt ]; then
  for pat in $SMART_PATTERNS; do
    run "find /opt -maxdepth 2 -type d -iname '$pat' 2>/dev/null | sort | head -40"
  done
fi

# =========================
# 4) SmartFriend Suite Root
# =========================
sec "SmartFriend Suite Root Structure"
if [ -d "$APP_ROOT" ]; then
  run "ls -la '$APP_ROOT'"
  run "find '$APP_ROOT' -maxdepth 2 -type d | sort"
else
  echo "[CRIT] APP_ROOT not found: $APP_ROOT" | teeout
fi

# =========================
# 5) Services Inventory (systemd)
# =========================
sec "Systemd Services Inventory (SmartFriend / DeepSeek / FFactory)"

UNITS=(
  smartfriend-smartcore.service
  smartfriend-unified.service
  smartfriend-api.service
  smartfrind-gateway.service
  deepseek-api.service
  ff-board.service
  ff-healthd.service
)

for u in "${UNITS[@]}"; do
  echo | teeout
  echo "##### $u #####" | teeout
  if systemctl list-unit-files "$u" >/dev/null 2>&1; then
    echo "-- systemctl status (short) --" | teeout
    run "systemctl status '$u' --no-pager -n 5 || true"
    echo "-- systemctl cat --" | teeout
    run "systemctl cat '$u' || true"
  else
    echo "[WARN] unit not found: $u" | teeout
  fi
done

# =========================
# 6) Databases (Postgres / Redis / SQLite)
# =========================
sec "PostgreSQL Check"
if ss -tlnp | grep -q ":5432"; then
  echo "[+] Postgres listening on 5432" | teeout
  if command -v pg_isready >/dev/null 2>&1; then
    run "pg_isready || true"
  fi
  if command -v psql >/dev/null 2>&1; then
    run "psql -lqt 2>/dev/null | awk '{print \$1}' | sed '/^$/d' | head -20"
  else
    echo "[WARN] psql command not available" | teeout
  fi
else
  echo "[WARN] Postgres not listening on 5432" | teeout
fi

sec "Redis Check"
if ss -tlnp | grep -q ":6379"; then
  if command -v redis-cli >/dev/null 2>&1; then
    run "redis-cli ping || true"
  else
    echo "[WARN] redis-cli not installed" | teeout
  fi
else
  echo "[INFO] Redis not listening on 6379" | teeout
fi

sec "SQLite Databases – SmartFriend Suite"
if [ -d "$APP_ROOT/data" ]; then
  for db in "$APP_ROOT"/data/*.db; do
    [ -f "$db" ] || continue
    size=$(stat -c%s "$db" 2>/dev/null || echo 0)
    echo "[DB] $(basename "$db") - ${size} bytes" | teeout
    run "sqlite3 '$db' '.tables' || true"
  done
else
  echo "[WARN] data directory not found under $APP_ROOT" | teeout
fi

sec "SQLite Databases – FFactory"
if [ -d /opt/ffactory ]; then
  for db in /opt/ffactory/**/*.db /opt/ffactory/*.db; do
    [ -f "$db" ] || continue
    size=$(stat -c%s "$db" 2>/dev/null || echo 0)
    echo "[DB-FF] $(basename "$db") - ${size} bytes" | teeout
    run "sqlite3 '$db' '.tables' || true"
  done 2>/dev/null || true
else
  echo "[INFO] /opt/ffactory not found" | teeout
fi

# =========================
# 7) ENV / Identity
# =========================
sec "ENV / Identity Summary"
if [ -f "$APP_ROOT/ENV/identity.env" ]; then
  run "ls -l '$APP_ROOT/ENV/identity.env'"
  echo "[*] SMART_CORE + bots keys (masked)" | teeout
  run "grep -E '^(SMART_CORE_|DEV_BOT_TOKEN|FORENSIC_BOT_TOKEN|ASSISTANT_BOT_TOKEN)' '$APP_ROOT/ENV/identity.env' | sed 's/=.*/=***HIDDEN***/'"
else
  echo "[CRIT] identity.env missing under $APP_ROOT/ENV" | teeout
fi

# =========================
# 8) Python / Tooling / Imports
# =========================
sec "Python / Tooling Check"
if command -v python3 >/dev/null 2>&1; then
  run "python3 --version"
else
  echo "[CRIT] python3 not found" | teeout
fi
if command -v pip3 >/dev/null 2>&1; then
  run "pip3 --version"
else
  echo "[WARN] pip3 not found" | teeout
fi
if command -v uvicorn >/dev/null 2>&1; then
  run "uvicorn --version"
else
  echo "[WARN] uvicorn not found in PATH" | teeout
fi

sec "Core Python Imports (smart_core / packages)"
if [ -d "$APP_ROOT" ]; then
  run "python3 - <<'PY'
import sys, importlib

root = '$APP_ROOT'
if root not in sys.path:
    sys.path.append(root)

modules = [
    'smart_core.config',
    'smart_core.app',
    'smart_core.router_core',
    'packages.core',
    'packages.memory',
    'packages.search',
]

for m in modules:
    try:
        mod = importlib.import_module(m)
        print(f'[OK] import {m} ->', getattr(mod, '__file__', 'built-in'))
    except Exception as e:
        print(f'[ERR] import {m} failed:', e)
PY"
else
  echo "[CRIT] APP_ROOT missing; cannot test imports" | teeout
fi

# =========================
# 9) Smart Core File-Level Checks
# =========================
sec "Smart Core – File-Level Checks"
CORE_DIR="$APP_ROOT/smart_core"
if [ -d "$CORE_DIR" ]; then
  run "ls -la '$CORE_DIR'"
  for file in config.py personas.py memory.py router_core.py app.py __init__.py; do
    if [ -f "$CORE_DIR/$file" ]; then
      size=$(stat -c%s "$CORE_DIR/$file" 2>/dev/null || echo "0")
      lines=$(wc -l < "$CORE_DIR/$file" 2>/dev/null || echo "0")
      echo "  $file - $lines سطر، $size بايت" | teeout
    else
      echo "  $file - غير موجود" | teeout
    fi
  done
else
  echo "[WARN] smart_core directory not found under $APP_ROOT" | teeout
fi

# =========================
# 10) HTTP Health Checks (no auto-start)
# =========================
sec "HTTP Checks for Running Services (no auto-start)"

check_http(){
  local name="$1"
  local port="$2"
  local path="$3"
  if ss -tlnp | grep -q ":${port}"; then
    echo "[+] $name appears LISTENING on port $port" | teeout
    run "curl -s 'http://127.0.0.1:${port}${path}' || echo '${name} HTTP check failed'"
  else
    echo "[WARN] $name not listening on port $port" | teeout
  fi
}

check_http "Smart Core"        8211 "/"
check_http "Memory API"        8214 "/health"
check_http "Unified API"       8220 "/health"
check_http "FFactory Gateway"  8170 "/health"
check_http "FFactory Main"     8000 "/"
check_http "FFactory Healthd"  9191 "/health"

# =========================
# 11) Git / Review Repos
# =========================
sec "Git / Review Repos (smartfriend_review)"
if [ -d "$REVIEW_ROOT" ]; then
  for repo in smartfriend-complete-system ffactory smartfrind smartfriend-suite; do
    if [ -d "$REVIEW_ROOT/$repo/.git" ]; then
      sec "Git snapshot: $repo (review clone)"
      run "cd '$REVIEW_ROOT/$repo' && pwd"
      run "cd '$REVIEW_ROOT/$repo' && git remote -v | head -6"
      run "cd '$REVIEW_ROOT/$repo' && git status -sb || true"
      run "cd '$REVIEW_ROOT/$repo' && git log -1 --oneline || echo 'no commits'"
      run "cd '$REVIEW_ROOT/$repo' && find . -maxdepth 2 -type d | grep -v '\\.git' | head -20"
    fi
  done

  if [ -d "$REVIEW_ROOT/smartfriend-suite/.git" ] && [ -d "$APP_ROOT" ]; then
    sec "Diff summary: /opt vs review (smart_core / gateway / factory)"
    for d in smart_core gateway factory; do
      if [ -d "$APP_ROOT/$d" ] && [ -d "$REVIEW_ROOT/smartfriend-suite/$d" ]; then
        echo "-- $d --" | teeout
        run "diff -qr '$APP_ROOT/$d' '$REVIEW_ROOT/smartfriend-suite/$d' | head -20 || true"
      fi
    done
  fi
else
  echo "[INFO] REVIEW_ROOT not found: $REVIEW_ROOT" | teeout
fi

# =========================
# 12) Executive Summary
# =========================
sec "Executive Summary – Runtime View"

svc_status(){
  local name="$1"
  local port="$2"
  if ss -tlnp | grep -q ":${port}"; then
    echo "  [ACTIVE] $name (port $port)" | teeout
  else
    echo "  [INACTIVE] $name (port $port)" | teeout
  fi
}

echo "- Services:" | teeout
svc_status "Smart Core"        8211
svc_status "Memory API"        8214
svc_status "Unified API"       8220
svc_status "FFactory Gateway"  8170
svc_status "FFactory Main"     8000
svc_status "FFactory Healthd"  9191

echo "" | teeout
echo "- Databases (SQLite under smartfriend-suite/data):" | teeout
if [ -d "$APP_ROOT/data" ]; then
  run "ls -1 '$APP_ROOT'/data/*.db 2>/dev/null || echo '  (none)'"
else
  echo "  data/ directory missing" | teeout
fi

echo "" | teeout
echo "- Key Directories Summary:" | teeout
for d in /opt/smartfriend-suite /opt/smartfrind /opt/ffactory; do
  if [ -d "$d" ]; then
    run "du -sh '$d'"
  else
    echo "  [MISS] $d" | teeout
  fi
done

echo "" | teeout
echo "[*] Global audit completed @ $(date '+%Y-%m-%d %H:%M:%S')" | teeout
echo "[*] Report directory: $OUT" | teeout
