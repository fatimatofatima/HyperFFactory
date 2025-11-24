#!/usr/bin/env bash
# HyperFFactory – Classify imported GitHub repos under imported/..../sources/repos/https-github.com-*
# الهدف:
#   - اكتشاف كل السكربتات/المجلدات اللي جاية من repos خارجية (pytorch, scikit-learn, fastapi, ...)
#   - تجميعها حسب اسم الريبو الأصلي
#   - توليد:
#       1) تقرير repos + counts
#       2) اقتراحات gitignore لهذه المسارات
#       3) ملخص مختصر

set -euo pipefail

ROOT="/root/HyperFFactory"
cd "$ROOT"

TS="$(date +%Y%m%d_%H%M%S)"
REPORT_DIR="reports"
mkdir -p "$REPORT_DIR"

REPOS_REPORT="${REPORT_DIR}/hf_imported_github_repos_${TS}.log"
GITIGNORE_SUG="${REPORT_DIR}/hf_imported_github_gitignore_${TS}.txt"
SUMMARY="${REPORT_DIR}/hf_imported_github_summary_${TS}.log"

echo "==================================================" | tee "$SUMMARY"
echo "🧩 HyperFFactory – Imported GitHub Repos Classification" | tee -a "$SUMMARY"
echo "ROOT   : ${ROOT}" | tee -a "$SUMMARY"
echo "TIME   : ${TS}" | tee -a "$SUMMARY"
echo "REPORT : ${REPOS_REPORT}" | tee -a "$SUMMARY"
echo "IGNORE : ${GITIGNORE_SUG}" | tee -a "$SUMMARY"
echo "==================================================" | tee -a "$SUMMARY"
echo | tee -a "$SUMMARY"

# 1) اجمع كل المسارات اللي تحتوي على https-github.com-... داخل sources/repos
echo "🔍 جمع المسارات المستوردة من GitHub..." | tee -a "$SUMMARY"

MAP_FILE="$(mktemp)"
trap 'rm -f "$MAP_FILE"' EXIT

find . -type f -path "*sources/repos/https-github.com-*.git/*" 2>/dev/null > "$MAP_FILE" || true

if [[ ! -s "$MAP_FILE" ]]; then
  echo "❌ لا توجد مسارات من نوع sources/repos/https-github.com-*.git/* داخل الشجرة." | tee -a "$SUMMARY"
  exit 0
fi

TOTAL_FILES="$(wc -l < "$MAP_FILE" | tr -d ' ')"
echo "✅ عدد الملفات المستوردة من GitHub: ${TOTAL_FILES}" | tee -a "$SUMMARY"
echo | tee -a "$SUMMARY"

# 2) استخرج اسم الريبو من المسار
# شكل القطعة:
#   .../sources/repos/https-github.com-ORG-REPO.git/PATH/TO/FILE
# نحتاج نرجعها لـ ORG/REPO

echo "📦 تجميع الملفات حسب الريبو الأصلي..." | tee -a "$SUMMARY"

awk -F'sources/repos/' '
  /https-github.com-/ {
    split($2, parts, "/")
    repo_part = parts[1]         # https-github.com-ORG-REPO.git
    # إزالة prefix https-github.com-
    sub(/^https-github.com-/, "", repo_part)
    # إزالة suffix .git إن وجد
    sub(/\.git$/, "", repo_part)
    # استبدال - الأول بـ / للحصول على ORG/REPO تقريبًا
    org_repo = repo_part
    sub(/-/, "/", org_repo)
    print org_repo "\t" $0
  }
' "$MAP_FILE" > "${REPOS_REPORT}"

# 3) احسب عدد الملفات لكل ريبو
echo "==================================================" | tee -a "$REPOS_REPORT"
echo "🧩 Imported GitHub Repos – File Mapping" | tee -a "$REPOS_REPORT"
echo "Generated at: ${TS}" | tee -a "$REPOS_REPORT"
echo "==================================================" | tee -a "$REPOS_REPORT"
echo >> "$REPOS_REPORT"

REPOS_SUMMARY_TMP="$(mktemp)"

cut -f1 "$REPOS_REPORT" | sort | uniq -c | sort -nr > "$REPOS_SUMMARY_TMP"

echo "📊 ملخص عدد الملفات لكل ريبو:" | tee -a "$SUMMARY"
echo >> "$SUMMARY"
while read -r count repo; do
  printf "  - %-40s : %s files\n" "$repo" "$count" | tee -a "$SUMMARY"
done < "$REPOS_SUMMARY_TMP"

echo >> "$REPOS_REPORT"
echo "📊 Repos summary (count repo):" >> "$REPOS_REPORT"
cat "$REPOS_SUMMARY_TMP" >> "$REPOS_REPORT"

# 4) توليد اقتراحات gitignore لكل ريبو (كجذر مجلد)
echo "🧾 توليد اقتراحات .gitignore..." | tee -a "$SUMMARY"
{
  echo "# HyperFFactory – Suggested ignore for imported GitHub repos (${TS})"
  echo "# هذه مسارات snapshots من مستودعات خارجية (pytorch, scikit-learn, fastapi, ...)"
  echo "# راجعها أولًا ثم انسخ ما يناسبك إلى .gitignore الرئيسية."
  echo
  sort -u "$MAP_FILE" | while read -r path; do
    # اقطع المسار حتى جذر الـ repo snapshot (حتى .git)
    # مثال:
    #   ./imported/opt/.../sources/repos/https-github.com-pytorch-pytorch.git/.ci/pytorch/test.sh
    # ⇒  ./imported/opt/.../sources/repos/https-github.com-pytorch-pytorch.git/
    clean="${path#./}"
    prefix="${clean%/*}" # خطوة مبدئية
    # قص حتى ".git/" الأولى
    case "$clean" in
      *".git/"*)
        repo_root="${clean%%.git/*}.git/"
        ;;
      *)
        # fallback: لحد repo name
        repo_root="$prefix/"
        ;;
    esac
    echo "$repo_root"
  done | sort -u
} > "$GITIGNORE_SUG"

echo "✅ انتهى التصنيف. الملفات الناتجة:" | tee -a "$SUMMARY"
echo "  - تقرير مفصل لكل ملف + ريبو  : ${REPOS_REPORT}" | tee -a "$SUMMARY"
echo "  - اقتراحات gitignore للـ repos : ${GITIGNORE_SUG}" | tee -a "$SUMMARY"
echo "  - ملخص عام                     : ${SUMMARY}" | tee -a "$SUMMARY"
