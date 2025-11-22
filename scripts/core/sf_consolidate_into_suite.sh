#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

MAIN="/opt/smartfriend-suite"
IMPORT="$MAIN/imported"
LEGACY_DBS="$MAIN/var/legacy_dbs"

echo "=== SmartFriend Suite Consolidation (FILES ONLY – NO DELETE) ==="

if [ ! -d "$MAIN" ]; then
  echo "ERROR: $MAIN غير موجود. أوقف." >&2
  exit 1
fi

mkdir -p "$IMPORT" "$LEGACY_DBS"

copy_dir(){
  src="$1"
  name="$2"
  if [ -d "$src" ]; then
    dst="$IMPORT/$name"
    echo "--- نسخ $src -> $dst"
    mkdir -p "$(dirname "$dst")"
    rsync -a "$src"/ "$dst"/
  else
    echo "تخطي (غير موجود): $src"
  fi
}

echo ">> تجميع المشاريع / الكود داخل السويت"

copy_dir "/opt/SmartFriend"              "legacy/SmartFriend"
copy_dir "/opt/smartfrind_unified"       "legacy/smartfrind_unified"
copy_dir "/opt/ULTIMATE_FUSION"          "legacy/ULTIMATE_FUSION"
copy_dir "/opt/SmartFrind_Miracle"       "legacy/SmartFrind_Miracle"
copy_dir "/opt/portsboard"               "apps/portsboard"
copy_dir "/opt/deepsseek"                "tools/deepsseek"
copy_dir "/opt/BRAIN_CORE"               "brain_core"
copy_dir "/opt/MyFriend"                 "myfriend"
copy_dir "/opt/COMPLETE_CODE_BACKUP"     "backups/COMPLETE_CODE_BACKUP"
copy_dir "/opt/report"                   "reports/root_opt_report"
copy_dir "/opt/secure"                   "secure_opt"

# نسخ أي مجلدات نسخ احتياطية للسويت/سمارتفريند
for d in /opt/smartfrind_backup_* /opt/smartfriend-suite-backup*; do
  if [ -d "$d" ]; then
    base="$(basename "$d")"
    copy_dir "$d" "backups/$base"
  fi
done

echo ">> تجميع toolchains والأدوات داخل السويت (android/jadx/... إلخ)"

copy_dir "/opt/android-sdk"              "toolchains/android-sdk"
copy_dir "/opt/jadx"                     "toolchains/jadx"
copy_dir "/opt/containerd"               "toolchains/containerd"
copy_dir "/opt/sf-venv"                  "toolchains/sf-venv"
copy_dir "/opt/bin"                      "toolchains/root_bin"
copy_dir "/opt/lib"                      "toolchains/root_lib"

echo ">> نسخ السكربتات المنفردة في /opt داخل السويت"

for f in \
  "/opt/smartfriend_builder.sh" \
  "/opt/smartfriend_quick.sh" \
  "/opt/ffactory_quick.sh" \
  "/opt/control_panel.sh" \
  "/opt/quick_start.sh" \
  "/opt/REAL_COMPLETE_INDEX.md" \
  "/opt/FINAL_REPORT.md" \
  "/opt/LICENSE" \
  "/opt/README.md" \
  "/opt/server_scripts.tar.gz"
do
  if [ -f "$f" ]; then
    base="$(basename "$f")"
    echo "--- نسخ ملف: $f -> $IMPORT/root_files/$base"
    mkdir -p "$IMPORT/root_files"
    cp -a "$f" "$IMPORT/root_files/$base"
  fi
done

echo ">> تجميع قواعد البيانات داخل legacy_dbs (نسخ فقط)"

# قاعدة السويت الأساسية – نتركها في مكانها، لكن نعمل نسخة احتياطية باسم واضح
if [ -f "$MAIN/var/db/smartfriend_unified.db" ]; then
  cp -a "$MAIN/var/db/smartfriend_unified.db" \
        "$LEGACY_DBS/smartfriend_unified_backup_$(date +%Y%m%d_%H%M%S).db"
fi

# smartfrind القديمة
if [ -f "/opt/smartfriend-suite/smartfrind/smartfrind.db" ]; then
  cp -a "/opt/smartfriend-suite/smartfrind/smartfrind.db" \
        "$LEGACY_DBS/smartfrind.db"
fi

# BRAIN_CORE
if [ -f "/opt/BRAIN_CORE/memory/shared.db" ]; then
  cp -a "/opt/BRAIN_CORE/memory/shared.db" \
        "$LEGACY_DBS/brain_core_shared.db"
fi

# قواعد بيانات / ملفات ذاكرة إضافية إن وجدت
if [ -f "/opt/MyFriend/memory.db" ]; then
  cp -a "/opt/MyFriend/memory.db" "$LEGACY_DBS/myfriend_memory.db"
fi

echo
echo "=== الانتهاء من مرحلة الدمج غير التدميري (FILES ONLY) ==="
echo "كل شيء تم نسخه داخل: $IMPORT و $LEGACY_DBS"
echo "راجع المحتوى واختبر السويت قبل أي حذف."
