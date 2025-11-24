#!/usr/bin/env bash
set -Eeuo pipefail

HF_ROOT="/root/hyper-factory"

log() { echo "[$(date '+%F %T')] $*"; }
sep() { echo "------------------------------------------------------------"; }

echo "╔══════════════════════════════════════════════╗"
echo "║        Hyper Factory – Environment Check     ║"
echo "╚══════════════════════════════════════════════╝"
echo

# 1) معلومات عامة عن السيرفر
sep
log "System summary"
if [ -f /etc/os-release ]; then
  log "OS: $(grep '^PRETTY_NAME=' /etc/os-release | cut -d= -f2- | tr -d '\"')"
fi
log "Hostname: $(hostname)"
log "Uptime: $(uptime -p || true)"
echo
df -h / | sed '1q;2p'
echo
free -h || true
echo

# 2) التحقق من مجلد hyper-factory
sep
log "Checking Hyper Factory root: $HF_ROOT"
if [ ! -d "$HF_ROOT" ]; then
  log "❌ المسار $HF_ROOT غير موجود – قبل أي دمج/استكمال لازم نعمل git clone من الريبو."
  exit 1
fi

cd "$HF_ROOT"

# 3) حالة git مقابل الريبو
sep
log "Git status (hyper-factory repo)"
if [ -d ".git" ]; then
  log "Remotes:"
  git remote -v 2>/dev/null | sed 's/^/   /' || true
  echo
  log "Last local commit:"
  git log -1 --oneline 2>/dev/null || echo "   (no commits info)"
else
  log "⚠️ هذا المجلد لا يحتوي .git (ليس clone مباشر من GitHub)"
fi
echo

# 4) عرض هيكل المستوى الأعلى
sep
log "Top-level layout under $HF_ROOT"
ls -1 || true
echo

# 5) فحص المجلدات الأساسية حسب تصميم Hyper Factory
sep
log "Checking required directories (design vs actual)"
required_dirs=(
  "ai"
  "apps"
  "apps/backend_coach"
  "config"
  "scripts"
  "scripts/core"
  "scripts/ai"
  "data"
  "data/factory"
  "data/knowledge"
  "data/inbox"
  "data/raw"
  "data/processed"
  "data/semantic"
  "data/serving"
  "logs"
  "reports"
)

missing_dirs=0
for d in "${required_dirs[@]}"; do
  if [ -d "$HF_ROOT/$d" ]; then
    printf "✅ DIR  %-30s  (exists)\n" "$d"
  else
    printf "❌ DIR  %-30s  (MISSING)\n" "$d"
    missing_dirs=$((missing_dirs+1))
  fi
done
echo

# 6) فحص الملفات/السكربتات الأساسية (مرجع من الريبو)
sep
log "Checking key files"
required_files=(
  "README.md"
  "config/orchestrator.yaml"
  "scripts/core/ffactory.sh"
)

missing_files=0
for f in "${required_files[@]}"; do
  if [ -f "$HF_ROOT/$f" ]; then
    printf "✅ FILE %-30s  (exists)\n" "$f"
  else
    printf "❌ FILE %-30s  (MISSING)\n" "$f"
    missing_files=$((missing_files+1))
  fi
done
echo

# 7) فحص قواعد البيانات التشغيلية لـ Hyper Factory
sep
log "Checking runtime databases (factory / knowledge)"
dbs=(
  "data/factory/factory.db"
  "data/knowledge/knowledge.db"
)

for db in "${dbs[@]}"; do
  if [ -f "$HF_ROOT/$db" ]; then
    size=$(du -h "$HF_ROOT/$db" 2>/dev/null | awk '{print $1}')
    printf "✅ DB   %-35s  size=%s\n" "$db" "$size"
  else
    printf "⚠️ DB   %-35s  (not found – سيتم إنشاؤها/ترحيلها لاحقًا)\n" "$db"
  fi
done
echo

# 8) ملخص النواقص
sep
log "Summary"
log "Missing directories : $missing_dirs"
log "Missing key files   : $missing_files"
echo

if [ "$missing_dirs" -eq 0 ] && [ "$missing_files" -eq 0 ]; then
  log "✅ Hyper Factory layout looks complete structurally. النواقص – لو وُجدت – ستكون في السكربتات المخصّصة والربط مع السيرفر."
else
  log "⚠️ يوجد نواقص في الهيكل. الخطوة التالية ستكون: استكمال هذه العناصر من الريبو أو من النسخ الاحتياطية الموجودة على السيرفر."
fi

echo
log "Done."
