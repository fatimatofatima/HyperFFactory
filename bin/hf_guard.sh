#!/usr/bin/env bash
# HyperFFactory Guard – يمنع التشغيل من خارج الهيكل الموحّد
set -u -o pipefail

LOG_DIR="/root/HyperFFactory/reports"
LOG_FILE="$LOG_DIR/hf_guard.log"
mkdir -p "$LOG_DIR"

STAMP="$(date '+%Y-%m-%d %H:%M:%S %z')"
USER_NAME="${USER:-unknown}"
PWD_NOW="$(pwd)"
CMD_STR="$*"

is_allowed_dir() {
  case "$PWD_NOW" in
    /root|/root/HyperFFactory|/root/HyperFFactory/*|/opt/smartfriend-suite|/opt/smartfriend-suite/*|/opt/ffactory|/opt/ffactory/*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

if [ "$#" -eq 0 ]; then
  cat <<MSG
[HF-GUARD] استعمال:
  $(basename "$0") <أمر> [معاملات...]

الغرض:
  منع تشغيل السكربتات من خارج الهيكل الموحّد،
  وتوثيق كل الأوامر في:
  $LOG_FILE
MSG
  exit 1
fi

if ! is_allowed_dir; then
  {
    echo "$STAMP | USER=$USER_NAME | PWD=$PWD_NOW | STATUS=BLOCKED | CMD=$CMD_STR"
  } >> "$LOG_FILE"

  cat <<MSG
============================================================
[HF-GUARD] تشغيل مرفوض
============================================================
المسار الحالي:
  $PWD_NOW

سياسة التشغيل:
  - لا تشغيل من خارج الهيكل الموحّد.
  - الهدف التجميع والتكامل داخل:
      /root/HyperFFactory
      /opt/smartfriend-suite
      /opt/ffactory

أي سكربت يعمل من هذا المسار يعتبر:
  "مخالفة لسياسة الهيكل الموحّد" و"تخريب تشغيلي" يجب إصلاحه.

رجاءً:
  انتقل إلى مسار معتمد ثم أعد تنفيذ الأمر عبر hf_guard.
============================================================
MSG
  exit 2
fi

{
  echo "$STAMP | USER=$USER_NAME | PWD=$PWD_NOW | STATUS=RUN | CMD=$CMD_STR"
} >> "$LOG_FILE"

echo "------------------------------------------------------------"
echo "[HF-GUARD] تنفيذ من داخل الهيكل الموحّد مسموح – جاري التنفيذ:"
echo "PWD = $PWD_NOW"
echo "CMD = $CMD_STR"
echo "------------------------------------------------------------"

# تنفيذ الأمر الفعلي
"$@"
RC=$?

{
  echo "$STAMP | USER=$USER_NAME | PWD=$PWD_NOW | STATUS=EXIT:$RC | CMD=$CMD_STR"
} >> "$LOG_FILE"

echo "------------------------------------------------------------"
echo "[HF-GUARD] انتهى الأمر بحالة خروج = $RC"
echo "سياسة التشغيل محفوظة: لا تشغيل من خارج الهيكل الموحّد."
echo "------------------------------------------------------------"

exit "$RC"
