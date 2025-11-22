#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

# ألوان بسيطة
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

section()  { echo -e "\n${BLUE}=== $* ===${NC}"; }
info()     { echo -e "${CYAN}[*] $*${NC}"; }
warn()     { echo -e "${YELLOW}[!] $*${NC}"; }
ok()       { echo -e "${GREEN}[OK] $*${NC}"; }
err()      { echo -e "${RED}[ERR] $*${NC}"; }

APP_ROOT="/opt/smartfriend-suite"

# قائمة الخدمات المستهدفة (sf / smartfriend / smartfrind)
SERVICES=(
  sf-audit-bot.service
  sf-backup.service
  sf-bot-assistant.service
  sf-bot-behavior.service
  sf-bot-dev.service
  sf-bot-model.service
  sf-bot-programmer.service
  sf-bot.service
  sf-cognitive.service
  sf-core.service
  sf-db-backup.service
  sf-db-maintenance.service
  sf-download.service
  sf-factory.service
  sf-fts-maint.service
  sf-health.service
  sf-ingest.service
  sf-kb-build.service
  sf-keys-rotate.service
  sf-learn.service
  sf-learning.service
  sf-memory.service
  sf-service-template@.service
  sf-smartfactory.service
  sf-smartfriend.service
  sf-smartfrind.service
  sf-smoke.service
  sf-spider.service
  sf-telegram-audit.service
  sf-telegram.service
  sf-unified.service
  sf-web.service
  smartfriend-api.service
  smartfriend-hybrid.service
  smartfriend-smartcore.service
  smartfriend-unified.service
  smartfrind-advanced.service
  smartfrind-ai-gateway.service
  smartfrind-api.service
  smartfrind-ask.service
  smartfrind-autolearn.service
  smartfrind-backup.service
  smartfrind-bot.service
  smartfrind-cma-sync.service
  smartfrind-core-watchdog.service
  smartfrind-core.service
  smartfrind-delta.sh.service
  smartfrind-envwatch.service
  smartfrind-final.service
  smartfrind-gateway.service
  smartfrind-guard.service
  smartfrind-guardian.service
  smartfrind-harvest.service
  smartfrind-ingest.service
  smartfrind-learner.service
  smartfrind-learning-agent.service
  smartfrind-learning.service
  smartfrind-local.service
  smartfrind-monitor.service
)

service_exec_path() {
    local unit="$1"
    systemctl show "$unit" -p ExecStart 2>/dev/null \
      | sed -n 's/^ExecStart=\(-\)\{0,1\}\(\/[^ ]*\).*/\2/p' \
      | head -n1
}

# إنشاء stub آمن لملف ExecStart مفقود (يمنع فشل التايمر لكنه لا ينفّذ منطق حقيقي)
ensure_stub() {
    local path="$1"
    local label="$2"

    if [ -x "$path" ]; then
        ok "الملف موجود وقابل للتنفيذ: $path"
        return 0
    fi

    warn "الملف مفقود أو غير قابل للتنفيذ، إنشاء stub مؤقت: $path"
    mkdir -p "$(dirname "$path")"
    cat > "$path" <<'STUB'
#!/usr/bin/env bash
echo "[SF STUB] هذا سكربت مؤقت تم إنشاؤه تلقائيًا حتى لا تفشل الخدمة."
echo "[SF STUB] لاحقًا استبدله بالسكربت الحقيقي الخاص بك."
exit 0
STUB
    chmod +x "$path"
    ok "تم إنشاء stub مؤقت: $path"
}

main() {
    section "التحقق من وجود مجلد السويت"

    if [ ! -d "$APP_ROOT" ]; then
        err "لم يتم العثور على $APP_ROOT → السويت غير منصّب في هذا المسار."
        exit 1
    fi
    ok "تم العثور على مجلد السويت: $APP_ROOT"

    section "فحص خدمات sf / smartfriend / smartfrind + إصلاحات محدودة"

    for u in "${SERVICES[@]}"; do
        info "فحص الوحدة: $u"

        if ! systemctl list-unit-files "$u" >/dev/null 2>&1; then
            warn "الوحدة غير معرّفة (list-unit-files): $u"
            continue
        fi

        active=$(systemctl is-active "$u" 2>/dev/null || echo "unknown")
        enabled=$(systemctl is-enabled "$u" 2>/dev/null || echo "unknown")
        exec=$(service_exec_path "$u" || true)

        echo "    enabled = $enabled, active = $active"
        echo "    Exec    = ${exec:-<no ExecStart>}"

        case "$u" in
          sf-download.service)
              # كان عندك خطأ EXEC لأن الملف مفقود → نضع stub مؤقت
              [ -n "$exec" ] && ensure_stub "$exec" "download"
              ;;
          sf-keys-rotate.service)
              # نفس الفكرة لمفاتيح JWT
              [ -n "$exec" ] && ensure_stub "$exec" "keys_rotate"
              ;;
          sf-db-backup.service|sf-backup.service)
              # لو سكربت الباك أب موجود لكن غير قابل للتنفيذ
              if [ -n "$exec" ] && [ -f "$exec" ] && [ ! -x "$exec" ]; then
                  warn "سكربت الباك أب موجود لكن غير قابل للتنفيذ، ضبط الصلاحيات: $exec"
                  chmod +x "$exec" || warn "تعذر ضبط الصلاحيات على $exec"
              fi
              ;;
          *)
              # لباقي الخدمات: عرض فقط، بدون تعديل تلقائي
              :
              ;;
        esac

        echo
    done

    section "ملاحظات تشغيلية"
    echo "هذا السكربت:"
    echo " - يفحص حالة الخدمات sf/smartfriend/smartfrind."
    echo " - ينشئ stubs مؤقتة فقط لـ sf-download و sf-keys-rotate لو ملفاتها مفقودة."
    echo " - لا يعمل restart أو enable أو disable لأي خدمة."
    echo
    echo "بعد الفحص يمكنك يدويًا تشغيل مثلًا:"
    echo "  systemctl restart sf-core.service sf-health.service sf-memory.service"
}

main "$@"
