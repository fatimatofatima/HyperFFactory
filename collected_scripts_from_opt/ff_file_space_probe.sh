#!/usr/bin/env bash
# ff_file_space_probe.sh — تقرير حي على الشاشة لتفاصيل المساحة لكل ملف مُدخل.
# قراءة-فقط. لا يحذف شيئًا.
# خيارات عبر المتغيّرات:
#   HASH=1    لحساب md5/sha256
#   USE_PV=1  لإظهار تقدّم أثناء الهاش (يتطلب pv)
#   SAMPLE=20 عدد أسطر العيّنة من الرأس/الذيل/قوائم الأرشيف

set -Eeuo pipefail
umask 027

USE_HASH="${HASH:-0}"
USE_PV="${USE_PV:-0}"
SAMPLE="${SAMPLE:-20}"

have(){ command -v "$1" >/dev/null 2>&1; }
hbytes(){ if have numfmt; then numfmt --to=iec-i --suffix=B "$1" 2>/dev/null || echo "$1"; else echo "$1"; fi; }

probe_file(){
  local f="$1"
  echo
  echo "════════════════════════════════════════════════════════════════"
  echo "ملف: $f"
  [ -e "$f" ] || { echo "✗ غير موجود"; return 1; }
  [ -f "$f" ] || { echo "✗ ليس ملفًا عاديًا"; return 0; }

  # تعاريف عامة
  local app used perc mime ftype owner group perm inode links birth mtime ctime
  app="$(stat -c '%s' "$f" 2>/dev/null || echo 0)"
  used="$(du -B1 -x "$f" 2>/dev/null | awk '{print $1}' | tail -n1)"
  used="${used:-0}"
  if [ "${app:-0}" -gt 0 ]; then perc=$(( used * 100 / app )); else perc=100; fi
  mime="$(file -b --mime "$f" 2>/dev/null || true)"
  ftype="$(file -b "$f" 2>/dev/null || true)"
  owner="$(stat -c '%U' "$f" 2>/dev/null || echo "?")"
  group="$(stat -c '%G' "$f" 2>/dev/null || echo "?")"
  perm="$(stat -c '%A (%a)' "$f" 2>/dev/null || echo "?")"
  inode="$(stat -c '%i' "$f" 2>/dev/null || echo "?")"
  links="$(stat -c '%h' "$f" 2>/dev/null || echo "?")"
  birth="$(stat -c '%w' "$f" 2>/dev/null || echo "-")"
  mtime="$(stat -c '%y' "$f" 2>/dev/null || echo "-")"
  ctime="$(stat -c '%z' "$f" 2>/dev/null || echo "-")"

  echo "• الحجم الظاهري (Apparent): $(hbytes "$app")"
  echo "• الحجم على القرص (Disk-used): $(hbytes "$used")   ← Utilization: ${perc}%"
  if [ "$perc" -lt 70 ]; then
    echo "• ملاحظة: ملف Sparse مرجّح (المستخدم ≪ الظاهري)"
  fi
  echo "• النوع: $ftype"
  echo "• MIME : $mime"
  echo "• المالك/المجموعة: $owner:$group   • الصلاحيات: $perm"
  echo "• inode: $inode   • الروابط: $links"
  echo "• الميلاد: $birth   • التعديل: $mtime   • التغيير: $ctime"

  echo
  echo "[df] نقطة التركيب/الجهاز:"
  df -h "$f" | sed -n '1,2p' || true

  echo
  echo "[stat]"
  stat "$f" || true

  echo
  echo "[تحليل امتداد/أرشيف]"
  case "$f" in
    *.tar.zst)
      have zstd && have tar && { echo "zstd -lv:"; zstd -lv "$f" 2>/dev/null || true
        echo; echo "tar --list (أول $SAMPLE):"; tar --use-compress-program zstd -tf "$f" 2>/dev/null | head -n "$SAMPLE" || true; }
      ;;
    *.zst)
      have zstd && { echo "zstd -lv:"; zstd -lv "$f" 2>/dev/null || true; }
      ;;
    *.tar.gz|*.tgz)
      have tar && { echo "tar -tzf (أول $SAMPLE):"; tar -tzf "$f" 2>/dev/null | head -n "$SAMPLE" || true; }
      have gzip && { echo; echo "gzip -l:"; gzip -l "$f" 2>/dev/null || true; }
      ;;
    *.gz)
      have gzip && { echo "gzip -l:"; gzip -l "$f" 2>/dev/null || true; }
      ;;
    *.xz)
      have xz && { echo "xz -l --verbose:"; xz -l --verbose "$f" 2>/dev/null || true; }
      ;;
    *.bz2)
      have bzip2 && { echo "bzip2 -tvv (ملخص):"; bzip2 -tvv "$f" 2>&1 | head -n 20 || true; }
      ;;
    *.zip)
      have unzip && { echo "قائمة zip (أول $SAMPLE):"; unzip -Z1 "$f" 2>/dev/null | head -n "$SAMPLE" || true; }
      ;;
    *.tar)
      have tar && { echo "tar -tf (أول $SAMPLE):"; tar -tf "$f" 2>/dev/null | head -n "$SAMPLE" || true; }
      ;;
  esac

  echo
  if [[ "$ftype" == *"filesystem data"* ]] || [[ "$f" == *.img ]] || [[ "$f" == *.iso ]]; then
    echo "[صورة/نظام ملفات]"
    have parted && { echo "parted -sm unit B print:"; parted -sm "$f" unit B print 2>/dev/null || true; }
    have dumpe2fs && { echo; echo "dumpe2fs -h (ملخص ext):"; dumpe2fs -h "$f" 2>/dev/null | sed -n '1,60p' || true; }
  fi

  echo
  echo "[عينات محتوى]"
  if echo "$mime" | grep -qi '^text/'; then
    echo "-- head ($SAMPLE):"; head -n "$SAMPLE" "$f" 2>/dev/null || true
    echo "-- tail ($SAMPLE):"; tail -n "$SAMPLE" "$f" 2>/dev/null || true
  else
    have strings && { echo "-- strings -a -n 8 (أول $SAMPLE):"; strings -a -n 8 "$f" 2>/dev/null | head -n "$SAMPLE" || true; } || echo "strings غير متاح"
  fi

  echo
  echo "[مقابض مفتوحة]"
  have lsof && lsof -n "$f" 2>/dev/null | sed -n '1,40p' || echo "lsof غير متاح أو لا مقابض."

  if [ "$USE_HASH" -eq 1 ]; then
    echo
    echo "[Hashes]"
    if [ "$USE_PV" -eq 1 ] && have pv; then
      echo "- md5:";  pv -petra "$f" | md5sum  || true
      echo "- sha256:"; pv -petra "$f" | sha256sum || true
    else
      echo "- md5:";  md5sum "$f"    2>/dev/null || true
      echo "- sha256:"; sha256sum "$f" 2>/dev/null || true
    fi
  fi

  echo
  echo "[ملخّص سطر واحد]"
  printf "PATH=%s | APP=%s | USED=%s | UTIL=%s%% | MIME=%s\n" \
    "$f" "$(hbytes "$app")" "$(hbytes "$used")" "$perc" "$mime"
}

if [ "$#" -lt 1 ]; then
  echo "استخدام: ff_file_space_probe.sh <ملف> [ملف...]" >&2
  exit 2
fi

for f in "$@"; do
  probe_file "$f"
done
