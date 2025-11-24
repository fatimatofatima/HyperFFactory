#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

log()   { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
ok()    { echo "   ✅ $*"; }
warn()  { echo "   ⚠️  $*"; }
fail()  { echo "   ❌ $*"; }

# 1) تحديد جذر Hyper Factory على السيرفر
HF_ROOT=""

for cand in "/root/hyper-factory" "/root/hyper" "/opt/hyper-factory"; do
  if [ -d "$cand" ]; then
    HF_ROOT="$cand"
    break
  fi
done

if [ -z "$HF_ROOT" ]; then
  echo "❌ لم يتم العثور على مجلد hyper-factory على المسارات المتوقعة."
  echo "   عدّل المتغير HF_ROOT يدويًا في السكربت."
  exit 1
fi

REPORT_DIR="$HF_ROOT/reports"
mkdir -p "$REPORT_DIR"
REPORT_FILE="$REPORT_DIR/hyper_diag_$(date '+%Y%m%d_%H%M%S').txt"

log "Hyper Factory – Structure Diagnostics"
log "HF_ROOT = $HF_ROOT"
log "Report  = $REPORT_FILE"
echo >> "$REPORT_FILE"

check_dir() {
  local rel="$1"
  local path="$HF_ROOT/$rel"
  if [ -d "$path" ]; then
    echo "[DIR][OK]   $rel" >> "$REPORT_FILE"
  else
    echo "[DIR][MISS] $rel" >> "$REPORT_FILE"
  fi
}

check_file() {
  local rel="$1"
  local path="$HF_ROOT/$rel"
  if [ -f "$path" ]; then
    echo "[FILE][OK]   $rel" >> "$REPORT_FILE"
  else
    echo "[FILE][MISS] $rel" >> "$REPORT_FILE"
  fi
}

{
  echo "============================================================"
  echo " Hyper Factory – Structure Diagnostics"
  echo " Time : $(date '+%Y-%m-%d %H:%M:%S %z')"
  echo " Root : $HF_ROOT"
  echo "============================================================"
  echo

  echo "== 1) Basic directory layout =="
  check_dir "."
  check_dir "data"
  check_dir "data/factory"
  check_dir "data/knowledge"
  check_dir "data/raw"
  check_dir "data/semantic"
  check_dir "data/serving"
  check_dir "data/inbox"
  check_dir "logs"
  check_dir "reports"
  check_dir "config"
  check_dir "agents"
  check_dir "ai"
  check_dir "apps"
  check_dir "_backup_backend"
  echo

  echo "== 2) Core database files (from logs) =="
  check_file "data/factory/factory.db"
  check_file "data/knowledge/knowledge.db"
  echo

  echo "== 3) Git status (repo vs فعليًا على السيرفر) =="
  if [ -d "$HF_ROOT/.git" ]; then
    echo "[GIT] Repo detected under $HF_ROOT"
    current_branch=$(git -C "$HF_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "UNKNOWN")
    current_commit=$(git -C "$HF_ROOT" rev-parse HEAD 2>/dev/null || echo "UNKNOWN")
    echo "[GIT] Branch : $current_branch"
    echo "[GIT] Commit : $current_commit"
    echo

    tracked_count=$(git -C "$HF_ROOT" ls-files | wc -l | tr -d ' ')
    all_files_count=$(find "$HF_ROOT" -type f ! -path "$REPORT_FILE" | wc -l | tr -d ' ')
    echo "[GIT] Tracked files : $tracked_count"
    echo "[GIT] All files     : $all_files_count"
    echo

    echo "[GIT] Untracked (top 50):"
    git -C "$HF_ROOT" ls-files --others --exclude-standard | head -n 50
  else
    echo "[GIT] لا يوجد .git في $HF_ROOT (قد تكون نسخة بدون تتبع Git)."
  fi
  echo

  echo "== 4) apps/ inventory (مستوى أول وثاني) =="
  if [ -d "$HF_ROOT/apps" ]; then
    find "$HF_ROOT/apps" -maxdepth 2 -type d | sed "s|$HF_ROOT/||" | sort
  else
    echo "apps/ غير موجودة."
  fi
  echo

  echo "== 5) agents/ inventory (مستوى أول وثاني) =="
  if [ -d "$HF_ROOT/agents" ]; then
    find "$HF_ROOT/agents" -maxdepth 2 -type d | sed "s|$HF_ROOT/||" | sort
  else
    echo "agents/ غير موجودة."
  fi
  echo

  echo "== 6) ai/ inventory (مستوى أول وثاني) =="
  if [ -d "$HF_ROOT/ai" ]; then
    find "$HF_ROOT/ai" -maxdepth 2 -type d | sed "s|$HF_ROOT/||" | sort
  else
    echo "ai/ غير موجودة."
  fi
  echo

  echo "== 7) backend scripts snapshot (root level فقط) =="
  ls -1 "$HF_ROOT" | grep -E '\.sh$' || echo "لا توجد سكربتات *.sh في الجذر."
  echo

  echo "== 8) data volume overview =="
  if [ -d "$HF_ROOT/data" ]; then
    du -sh "$HF_ROOT/data"/* 2>/dev/null | sort -h
  else
    echo "مجلد data غير موجود."
  fi
  echo

} >> "$REPORT_FILE"

log "تم إنشاء تقرير الهيكل:"
log "  $REPORT_FILE"

echo
echo "ملحوظة: السكربت تشخيص فقط، لا يغيّر أي ملفات."
