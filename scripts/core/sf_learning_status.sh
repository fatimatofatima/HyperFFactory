#!/usr/bin/env bash
set -Eeuo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok(){ echo -e "${GREEN}[✓]${NC} $*"; }
warn(){ echo -e "${YELLOW}[!]${NC} $*"; }
err(){ echo -e "${RED}[✗]${NC} $*"; }

SM_DB="/var/lib/smartfrind/smart_memory.db"
CORE_DB="/opt/smartfrind/data/smartfrind.db"
CURRICULUM_DIR="/opt/smartfrind/curriculum"

echo "==========================================="
echo "   🧠 SmartFrind - Learning Status Check"
echo "==========================================="
echo

# 1) قواعد البيانات
echo "[i] Databases:"
for db in "$SM_DB" "$CORE_DB"; do
  if [ -f "$db" ]; then
    ok "DB exists: $db (size: $(du -h "$db" | cut -f1))"
  else
    warn "DB missing: $db"
  fi
done
echo

# 2) جداول المعرفة والذاكرة
if command -v sqlite3 >/dev/null 2>&1; then
  if [ -f "$SM_DB" ]; then
    echo "[i] Tables in smart_memory.db:"
    sqlite3 "$SM_DB" '.tables'
    echo
    for tbl in knowledge_base user_long_term_memory; do
      echo "  - $tbl:"
      sqlite3 "$SM_DB" "SELECT COUNT(*) FROM $tbl;" 2>/dev/null \
        || warn "    لا يمكن قراءة الجدول $tbl"
    done
    echo
  fi

  if [ -f "$CORE_DB" ]; then
    echo "[i] Tables in smartfrind.db (CORE):"
    sqlite3 "$CORE_DB" '.tables'
    echo "  - conscious_memory rows:"
    sqlite3 "$CORE_DB" "SELECT COUNT(*) FROM conscious_memory;" 2>/dev/null \
      || warn "    لا يمكن قراءة conscious_memory"
    echo
  fi
else
  err "sqlite3 غير مثبت - ثبّته لتقدر تفحص قواعد البيانات."
fi

# 3) ملفات المناهج
echo "[i] Curriculum directory:"
if [ -d "$CURRICULUM_DIR" ]; then
  ok "Exists: $CURRICULUM_DIR"
  echo "   Files:"
  find "$CURRICULUM_DIR" -maxdepth 2 -type f | sed 's/^/     - /' | head -20
else
  warn "Curriculum dir not found: $CURRICULUM_DIR"
fi
echo

# 4) أي أثار Spider / Crawler
echo "[i] Quick grep for spider/crawler in code:"
cd /opt/smartfrind || exit 0
grep -R -i -n -E 'spider|crawler|crawl' . 2>/dev/null | head -40 || \
  warn "لا توجد كلمات spider/crawler في الكود (أو عددها قليل جداً)."

echo
echo "==========================================="
echo "   ✅ Learning status check finished"
echo "==========================================="
