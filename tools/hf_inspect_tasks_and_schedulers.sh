#!/usr/bin/env bash
# HF Inspect – فحص حالة المهام + المجدولات بدون أي تعديل
set -euo pipefail

HYPER_ROOT="/root/HyperFFactory"
cd "$HYPER_ROOT" || {
  echo "❌ لا يمكن الدخول إلى $HYPER_ROOT"
  exit 1
}

TS_HUMAN="$(date '+%Y-%m-%d %H:%M:%S %z')"

echo "====================================================="
echo "HF Inspect – Tasks & Schedulers Status"
echo "====================================================="
echo "ROOT : $HYPER_ROOT"
echo "TIME : $TS_HUMAN"
echo

# دالة مساعدة لطباعة فواصل
sep() {
  echo
  echo "-----------------------------------------------------"
  echo "$1"
  echo "-----------------------------------------------------"
}

# 1) فحص hf_tasks.db (قائمة المهام الرسمية)
sep "1) hf_tasks.db – قائمة المهام حسب الحالة"
TASKS_DB="$HYPER_ROOT/db/meta/hf_tasks.db"

if [[ -f "$TASKS_DB" ]]; then
  echo "[i] استخدام قاعدة: $TASKS_DB"
  echo

  echo "[A] عدد المهام حسب الحالة:"
  sqlite3 "$TASKS_DB" "SELECT status, COUNT(*) FROM tasks GROUP BY status;" || echo "⚠️ خطأ أثناء قراءة tasks (group by status)"

  echo
  echo "[B] أهم المهام PLANNED (أعلى أولوية، أول 20):"
  sqlite3 -cmd ".headers on" -cmd ".mode column" "$TASKS_DB" "
    SELECT id, actor, scope, status, priority, title, created_at, updated_at
    FROM tasks
    WHERE status='PLANNED'
    ORDER BY priority ASC, id ASC
    LIMIT 20;
  " || echo "⚠️ خطأ أثناء قراءة المهام PLANNED"

  echo
  echo "[C] المهام RUNNING (إن وجدت):"
  sqlite3 -cmd ".headers on" -cmd ".mode column" "$TASKS_DB" "
    SELECT id, actor, scope, status, priority, title, created_at, updated_at
    FROM tasks
    WHERE status='RUNNING'
    ORDER BY id ASC;
  " || echo "⚠️ خطأ أثناء قراءة المهام RUNNING"

  echo
  echo "[D] المهام DONE المتعلقة بالتكامل (integrations) إن وجدت:"
  sqlite3 -cmd ".headers on" -cmd ".mode column" "$TASKS_DB" "
    SELECT id, actor, scope, status, priority, title, created_at, updated_at
    FROM tasks
    WHERE scope LIKE 'integration%' OR title LIKE '%تكامل%'
    ORDER BY id ASC;
  " || echo "⚠️ خطأ أثناء قراءة مهام التكامل"
else
  echo "⚠️ لا يوجد ملف: $TASKS_DB"
fi

# 2) فحص progress_log في hf_ops_meta.db
sep "2) hf_ops_meta.db – آخر 30 صف من progress_log (لو وجد)"
OPS_DB="$HYPER_ROOT/db/meta/hf_ops_meta.db"

if [[ -f "$OPS_DB" ]]; then
  HAS_PL=$(sqlite3 "$OPS_DB" "SELECT name FROM sqlite_master WHERE type='table' AND name='progress_log';" || true)
  if [[ -n "$HAS_PL" ]]; then
    echo "[i] استخدام قاعدة: $OPS_DB"
    echo "[i] آخر 30 صف:"
    sqlite3 -cmd ".headers on" -cmd ".mode column" "$OPS_DB" "
      SELECT id, script_name, action, path, status, details, ts
      FROM progress_log
      ORDER BY id DESC
      LIMIT 30;
    " || echo "⚠️ خطأ أثناء قراءة progress_log"
  else
    echo "ℹ️ لا يوجد جدول progress_log في $OPS_DB"
  fi
else
  echo "⚠️ لا يوجد ملف: $OPS_DB"
fi

# 3) فحص systemd timers المتعلقة بـ HyperFFactory
sep "3) systemd timers – أي تايمرز لها علاقة بـ HyperFFactory أو hf_ ؟"
if command -v systemctl >/dev/null 2>&1; then
  systemctl list-timers --all | grep -Ei 'hyper|hf_' || echo "ℹ️ لا يوجد timers مطابقة لـ (hyper|hf_)"
else
  echo "⚠️ systemctl غير متاح على هذا النظام."
fi

# 4) فحص cron jobs المتعلقة بـ HyperFFactory
sep "4) crontab (root) – أسطر لها علاقة بـ HyperFFactory أو hf_ ؟"
CRON_TMP="$(mktemp)"
if crontab -l >"$CRON_TMP" 2>/dev/null; then
  if grep -Ei 'hyper|hf_' "$CRON_TMP" >/dev/null 2>&1; then
    grep -Ei 'hyper|hf_' "$CRON_TMP"
  else
    echo "ℹ️ لا توجد أسطر تحتوي hyper أو hf_ في crontab root"
  fi
else
  echo "ℹ️ لا يوجد crontab لـ root أو لا يمكن قراءته"
fi
rm -f "$CRON_TMP"

# 5) العمليات الجارية (processes) المتعلقة بـ HyperFFactory
sep "5) العمليات الحالية (ps) المتعلقة بـ HyperFFactory/hf_"
ps aux | grep -Ei 'hyper|hf_' | grep -v grep || echo "ℹ️ لا توجد عمليات حالية باسم يحتوي hyper أو hf_"

# 6) ملاحظة عامة حول البطء (placeholder – شرح فقط)
sep "6) ملاحظة عامة"
echo "هذا السكربت لا يفسر البطء مباشرة، لكنه يعرض:"
echo " - عدد المهام PLANNED / RUNNING / DONE."
echo " - إن كان هناك timers أو cron تشغل سكربتات HyperFFactory تلقائيًا."
echo " - إن كان هناك عمليات hyper/hf_ شغّالة الآن وقد تكون بطيئة."
echo
echo "يمكن بعد ذلك قياس زمن تنفيذ بعض السكربتات يدويًا مثلاً:"
echo "  time bin/hf_health_all.sh"
echo "  time bin/hf_run_basic_pipeline.sh"
echo
echo "وبناءً على النتائج نحدد: هل البطء من نوعية السكربتات نفسها (فحص ملفات كثيرة/قواعد بيانات)،"
echo "أم من وجود مهام متداخلة أو تشغيل متكرر بلا فواصل."
