#!/usr/bin/env bash
# HyperFFactory – Server & Factory Status Check (READ-ONLY)
# - يفحص حالة النظام + HyperFFactory + meta DBs + workers + الأنظمة الخارجية
# - لا يشغّل خدمات ولا يغيّر أي ملف

set -euo pipefail

ROOT="${ROOT:-/root/HyperFFactory}"
META_DIR="$ROOT/db/meta"
TOOLS_DIR="$ROOT/tools"
WORKERS_DIR="$ROOT/workers"
LOGS_DIR="$ROOT/logs"

ts() {
  date +"%Y-%m-%dT%H:%M:%S%z"
}

section() {
  echo
  echo "=================================================="
  echo "[$(ts)] $1"
  echo "=================================================="
}

subsection() {
  echo
  echo "[$(ts)] --- $1 ---"
}

check_cmd() {
  local cmd="$1"
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "  [OK]  $cmd موجود"
    return 0
  else
    echo "  [MISS] $cmd غير موجود"
    return 1
  fi
}

check_path() {
  local p="$1"
  local label="$2"
  if [ -d "$p" ]; then
    echo "  [DIR OK]   $label : $p"
  elif [ -f "$p" ]; then
    echo "  [FILE OK]  $label : $p"
  else
    echo "  [MISSING]  $label : $p"
  fi
}

check_script() {
  local path="$1"
  local label="$2"
  if [ -f "$path" ]; then
    if [ -x "$path" ]; then
      echo "  [OK]   $label : موجود + قابل للتنفيذ → $path"
    else
      echo "  [WARN] $label : موجود ولكن غير قابل للتنفيذ (chmod +x) → $path"
    fi
  else
    echo "  [MISS] $label : غير موجود → $path"
  fi
}

short_sqlite_info() {
  local db_path="$1"
  local label="$2"

  if [ ! -f "$db_path" ]; then
    echo "  [MISS] $label : لا يوجد ملف DB ($db_path)"
    return
  fi

  local size
  size=$(stat -c '%s' "$db_path" 2>/dev/null || echo "0")
  echo "  [DB] $label"
  echo "       • الملف : $db_path"
  echo "       • الحجم : $size bytes"

  if ! command -v sqlite3 >/dev/null 2>&1; then
    echo "       • sqlite3 غير موجود – سيتم تخطي فحص الجداول."
    return
  fi

  local tables
  tables=$(sqlite3 "$db_path" "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;" 2>/dev/null || true)
  if [ -z "$tables" ]; then
    echo "       • الجداول: (لا توجد جداول)"
  else
    echo "       • الجداول:"
    echo "$tables" | sed 's/^/         - /'
  fi
}

#--------------------------------------
# [1] معلومات النظام العامة
#--------------------------------------
section "1) معلومات النظام العامة"

echo "  المضيف       : $(hostname)"
echo "  الوقت الحالي : $(date)"
echo

echo "  --- uptime / load ---"
uptime || true

echo
echo "  --- استخدام القرص (/) ---"
df -h / || true

echo
echo "  --- الذاكرة ---"
free -h || true

echo
echo "  --- أوامر أساسية ---"
check_cmd sqlite3
check_cmd git
check_cmd docker
check_cmd systemctl
check_cmd curl

#--------------------------------------
# [2] HyperFFactory – حالة المجلد و Git
#--------------------------------------
section "2) HyperFFactory – المجلد و Git"

check_path "$ROOT" "ROOT"

if [ -d "$ROOT/.git" ]; then
  echo
  echo "  --- حالة Git ---"
  (
    cd "$ROOT"
    echo "  الفرع الحالي:"
    git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "  (لا يمكن قراءة الفرع)"
    echo
    echo "  التغييرات غير الملتزمة (مختصر):"
    git status -sb 2>/dev/null || echo "  (لا يمكن قراءة status)"
  )
else
  echo "  [INFO] هذا المجلد لا يحتوي .git (لا يوجد مستودع Git محلي)."
fi

echo
echo "  --- المجلدات الأساسية ---"
check_path "$META_DIR"   "META_DIR"
check_path "$TOOLS_DIR"  "TOOLS_DIR"
check_path "$WORKERS_DIR" "WORKERS_DIR"
check_path "$LOGS_DIR"   "LOGS_DIR"

#--------------------------------------
# [3] Meta DBs – نظرة سريعة
#--------------------------------------
section "3) Meta DBs – نظرة سريعة"

if [ -d "$META_DIR" ]; then
  echo "  محتويات $META_DIR:"
  ls -1 "$META_DIR" || true
else
  echo "  [WARN] مجلد META غير موجود: $META_DIR"
fi

echo
echo "  --- قواعد البيانات الرئيسية ---"
short_sqlite_info "$META_DIR/hf_tasks.db"         "hf_tasks.db"
short_sqlite_info "$META_DIR/hf_errors.db"        "hf_errors.db"
short_sqlite_info "$META_DIR/hf_quality.db"       "hf_quality.db"
short_sqlite_info "$META_DIR/hf_learning.db"      "hf_learning.db"
short_sqlite_info "$META_DIR/hf_patterns.db"      "hf_patterns.db"
short_sqlite_info "$META_DIR/hf_ops_meta.db"      "hf_ops_meta.db"
short_sqlite_info "$META_DIR/hf_ops_meta_tasks.db" "hf_ops_meta_tasks.db"
short_sqlite_info "$META_DIR/hf_files_index.db"   "hf_files_index.db"
short_sqlite_info "$META_DIR/hf_registry.db"      "hf_registry.db"
short_sqlite_info "$META_DIR/hyper_meta.db"       "hyper_meta.db"

# تفاصيل إضافية لبعض الجداول المهمة (إذا وجدت)
if command -v sqlite3 >/dev/null 2>&1; then
  echo
  echo "  --- تفاصيل إضافية (hf_tasks.db) ---"
  if [ -f "$META_DIR/hf_tasks.db" ]; then
    sqlite3 "$META_DIR/hf_tasks.db" "SELECT name FROM sqlite_master WHERE type='table';" 2>/dev/null || true
    echo "    عدد المهام في جدول tasks (إن وجد):"
    sqlite3 "$META_DIR/hf_tasks.db" "SELECT COUNT(*) FROM tasks;" 2>/dev/null || echo "    (لا يمكن قراءة جدول tasks)"
    echo "    عدد المهام لـ actor = 'hf_db_manager' (إن وجد):"
    sqlite3 "$META_DIR/hf_tasks.db" "SELECT COUNT(*) FROM tasks WHERE actor='hf_db_manager';" 2>/dev/null || echo "    (لا يمكن قراءة tasks أو لا يوجد عمود actor)"
  else
    echo "    (hf_tasks.db غير موجود)"
  fi

  echo
  echo "  --- تفاصيل إضافية (hf_errors.db) ---"
  if [ -f "$META_DIR/hf_errors.db" ]; then
    echo "    عدد الجداول:"
    sqlite3 "$META_DIR/hf_errors.db" "SELECT COUNT(*) FROM sqlite_master WHERE type='table';" 2>/dev/null || echo "    (فشل فحص الجداول)"
    echo "    آخر 5 حوادث (إن وجد جدول incidents):"
    sqlite3 "$META_DIR/hf_errors.db" "SELECT * FROM incidents ORDER BY id DESC LIMIT 5;" 2>/dev/null || echo "    (لا يوجد جدول incidents أو لا يمكن قراءته)"
  else
    echo "    (hf_errors.db غير موجود)"
  fi
fi

#--------------------------------------
# [4] السكربتات الحرجة في tools/
#--------------------------------------
section "4) السكربتات الحرجة في tools/"

check_script "$TOOLS_DIR/hf_status_snapshot.sh"       "hf_status_snapshot"
check_script "$TOOLS_DIR/hf_kpi_snapshot.sh"          "hf_kpi_snapshot"
check_script "$TOOLS_DIR/hf_db_audit.sh"              "hf_db_audit"
check_script "$TOOLS_DIR/hf_truth_check_gaps.sh"      "hf_truth_check_gaps"
check_script "$TOOLS_DIR/hf_check_gaps.sh"            "hf_check_gaps"
check_script "$TOOLS_DIR/hf_stage10_governance_full.sh" "hf_stage10_governance_full"
check_script "$TOOLS_DIR/hf_registry_build.sh"        "hf_registry_build"
check_script "$TOOLS_DIR/hf_integration_phase_runner.sh" "hf_integration_phase_runner"
check_script "$TOOLS_DIR/hf_git_safe_server_sync.sh"  "hf_git_safe_server_sync"

#--------------------------------------
# [5] العمال داخل HyperFFactory
#--------------------------------------
section "5) العمال (workers) داخل HyperFFactory"

if [ -d "$WORKERS_DIR" ]; then
  echo "  محتويات $WORKERS_DIR:"
  ls -1 "$WORKERS_DIR" || true

  echo
  echo "  --- فحص العمال الأساسية ---"
  check_script "$WORKERS_DIR/ingestor_basic.sh"   "ingestor_basic.sh"
  check_script "$WORKERS_DIR/processor_basic.sh"  "processor_basic.sh"
  check_script "$WORKERS_DIR/analyzer_basic.sh"   "analyzer_basic.sh"
  check_script "$WORKERS_DIR/reporter_basic.sh"   "reporter_basic.sh"
else
  echo "  [WARN] مجلد workers غير موجود في $WORKERS_DIR"
fi

#--------------------------------------
# [6] مشاريع خارجية مرتبطة (hyper-factory / smartfriend / ffactory)
#--------------------------------------
section "6) المشاريع الخارجية المرتبطة"

check_path "/root/hyper-factory"      "/root/hyper-factory (القدرات القديمة)"
check_path "/opt/smartfriend-suite"   "/opt/smartfriend-suite (SmartFriend Suite)"
check_path "/opt/ffactory"            "/opt/ffactory (FFactory stack)"

#--------------------------------------
# [7] ملخص عالي المستوى
#--------------------------------------
section "7) ملخص عالي المستوى (للاستخدام اليدوي)"

echo "  • راجع القسم (3) لمعرفة حالة قواعد بيانات meta والجداول الموجودة."
echo "  • راجع القسم (4) لمعرفة السكربتات المفقودة التي تسبب SCRIPT_NOT_FOUND في الحوادث."
echo "  • راجع القسم (5) لتتأكد من تواجد العمال الأربعة الأساسية داخل HyperFFactory."
echo "  • راجع القسم (6) للتأكد من وجود المشاريع الخارجية المهمة على السيرفر."
echo
echo "[$(ts)] انتهاء فحص الوضع الفعلي."
