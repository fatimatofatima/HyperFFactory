#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

LOG_TAG="[SF-DECISION]"
OUT_DIR="/opt/smartfriend-suite/reports"
mkdir -p "$OUT_DIR"

echo "${LOG_TAG} البحث عن أحدث ملف Matrix..."
SRC_MATRIX="$(ls -1 ${OUT_DIR}/sf_suite_service_matrix_*.tsv 2>/dev/null | sort | tail -n 1 || true)"

if [[ -z "${SRC_MATRIX}" ]] || [[ ! -f "${SRC_MATRIX}" ]]; then
  echo "${LOG_TAG} لم يتم العثور على أي ملف Matrix في ${OUT_DIR}"
  exit 1
fi

TS="$(date +%Y%m%d_%H%M%S)"
OUT_DECISIONS="${OUT_DIR}/sf_suite_service_decisions_${TS}.tsv"

echo "${LOG_TAG} استخدام Matrix: ${SRC_MATRIX}"
echo "${LOG_TAG} كتابة قرار الخدمات في: ${OUT_DECISIONS}"

# ترويسة الملف الجديد (نفس الأعمدة + decision)
{
  echo -e "family\tunit\tkind\trole\tactive_state\tsub_state\tmain_pid\tports\tfragment_path\tdecision"
} > "${OUT_DECISIONS}"

# قراءة Matrix وتوليد decision
tail -n +2 "${SRC_MATRIX}" | \
while IFS=$'\t' read -r family unit kind role active_state sub_state main_pid ports fragment_path; do
  decision="REVIEW"

  case "${family}" in
    suite)
      case "${unit}" in
        # ===== Backups / Maintenance / Security / Ops =====
        sf-backup.service|sf-backup.timer)
          decision="KEEP"
          ;;
        sf-db-backup.service|sf-db-backup.timer)
          decision="KEEP"
          ;;
        sf-db-maintenance.service|sf-db-maintenance.timer)
          decision="KEEP"
          ;;
        sf-fts-maint.service|sf-fts-maint.timer)
          decision="KEEP"
          ;;
        sf-kb-build.service|sf-kb-build.timer)
          decision="KEEP"
          ;;
        sf-keys-rotate.service|sf-keys-rotate.timer)
          decision="KEEP"
          ;;
        sf-download.service|sf-download.timer)
          decision="KEEP"
          ;;
        sf-learn.service|sf-learn.timer)
          decision="KEEP"
          ;;
        sf-learning.service|sf-learning.timer)
          decision="KEEP"
          ;;
        sf-smoke.service|sf-smoke.timer)
          decision="KEEP"
          ;;
        sf-ingest.service|sf-spider.service)
          decision="KEEP"
          ;;

        # ===== Gateways / APIs / Bots / Factory =====
        sf-factory.service)
          decision="KEEP"
          ;;
        sf-core.service)
          decision="KEEP"
          ;;
        sf-unified.service)
          decision="KEEP"
          ;;
        sf-memory.service)
          decision="KEEP"
          ;;
        sf-telegram.service|sf-telegram-audit.service)
          decision="KEEP"
          ;;
        sf-bot.service|sf-bot-dev.service|sf-bot-model.service|sf-bot-programmer.service|sf-bot-assistant.service|sf-bot-behavior.service|sf-audit-bot.service)
          decision="KEEP"
          ;;
        sf-smartfactory.service|sf-smartfriend.service|sf-smartfrind.service)
          decision="KEEP"
          ;;
        sf-health.service)
          decision="KEEP"
          ;;

        # أي خدمة suite أخرى → تبقى تحت المراجعة
        *)
          decision="REVIEW"
          ;;
      esac
      ;;

    smartfrind)
      case "${unit}" in
        # ===== Backends أساسية نستخدمها كـ Backend فقط مؤقتًا =====
        smartfrind-core.service|smartfrind-gateway.service|smartfrind-api.service)
          decision="KEEP_BACKEND_ONLY"
          ;;
        smartfrind-harvest.service|smartfrind-harvest.timer)
          decision="KEEP_BACKEND_ONLY"
          ;;
        smartfrind-ingest.service|smartfrind-ingest.timer)
          decision="KEEP_BACKEND_ONLY"
          ;;
        smartfrind-raw-clean.service|smartfrind-raw-clean.timer)
          decision="KEEP_BACKEND_ONLY"
          ;;
        smartfrind-reflector.service|smartfrind-reflector.timer)
          decision="KEEP_BACKEND_ONLY"
          ;;
        smartfrind-core-watchdog.service|smartfrind-core-watchdog.timer)
          decision="KEEP_BACKEND_ONLY"
          ;;
        smartfrind-watchdog.service|smartfrind-watchdog.timer)
          decision="KEEP_BACKEND_ONLY"
          ;;
        smartfrind-guardian.service)
          decision="KEEP_BACKEND_ONLY"
          ;;

        # ===== أنظمة تعلم/بوت/حماية قديمة → مرشحة للإيقاف لاحقًا =====
        smartfrind-bot.service)
          decision="DEPRECATE_LATER"
          ;;
        smartfrind-backup.service|smartfrind-backup.timer)
          decision="DEPRECATE_LATER"
          ;;
        smartfrind-autolearn.service|smartfrind-autolearn.timer)
          decision="DEPRECATE_LATER"
          ;;
        smartfrind-learning.service|smartfrind-learning-agent.service|smartfrind-learning-agent.timer|smartfrind-learner.service|smartfrind-learner.timer|smartfrind-trainer.service)
          decision="DEPRECATE_LATER"
          ;;
        smartfrind-cma-sync.service|smartfrind-cma-sync.timer)
          decision="DEPRECATE_LATER"
          ;;
        smartfrind-guard.service|smartfrind-guard.timer|smartfrind-envwatch.service|smartfrind-envwatch.timer)
          decision="DEPRECATE_LATER"
          ;;
        smartfrind-monitor.service|smartfrind-runner.service|smartfrind-delta.sh.service|smartfrind-setup.sh.service)
          decision="DEPRECATE_LATER"
          ;;

        # ===== Gateways تجريبية ومتعددة (نفس الفكرة بواجهات مختلفة) =====
        smartfrind-advanced.service|smartfrind-ai-gateway.service|smartfrind-local.service|smartfrind-simple.service|smartfrind-ultra.service|smartfrind-final.service|smartfrind-qa.service|smartfrind-unified.service)
          decision="DEPRECATE_LATER"
          ;;

        # أي خدمة smartfrind أخرى → REVIEW
        *)
          decision="REVIEW"
          ;;
      esac
      ;;

    *)
      decision="REVIEW"
      ;;
  esac

  echo -e "${family}\t${unit}\t${kind}\t${role}\t${active_state}\t${sub_state}\t${main_pid}\t${ports}\t${fragment_path}\t${decision}" >> "${OUT_DECISIONS}"
done

echo "${LOG_TAG} DONE. Decisions matrix written to: ${OUT_DECISIONS}"
