#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-check}"      # check | run
BASE="/root/HyperFFactory"
VENV_DIR="${BASE}/.venv"
REQUIREMENTS="${BASE}/requirements_fixed.txt"

echo "====================================="
echo " HyperFFactory - Enhanced Bootstrap"
echo "====================================="
echo "Timestamp : $(date)"
echo "Hostname  : $(hostname)"
echo "Base Path : ${BASE}"
echo "Mode      : ${MODE}"
echo

# دالة صغيرة لاختيار docker compose المناسب
docker_compose_cmd() {
    if command -v docker >/dev/null 2>&1; then
        # نمط plugin الحديث
        echo "docker compose"
    elif command -v docker-compose >/dev/null 2>&1; then
        echo "docker-compose"
    else
        echo ""
    fi
}

# 1) فحص البيئة الأساسية
echo "---- [1] فحص البيئة الأساسية ----"
cd "${BASE}"

echo "📁 Git Status:"
if command -v git >/dev/null 2>&1; then
    git remote -v | head -2 || true
    git status --short | head -5 || true
    # عدّ الملفات المتغيرة/غير المتتبعة بطريقة آمنة مع set -e
    GIT_CHANGED_COUNT=$( { git status --short 2>/dev/null || true; } | wc -l | tr -d ' ')
    echo "... (و ${GIT_CHANGED_COUNT} ملف متغير/غير متتبع)"
else
    echo "⚠️ git غير متوفر في PATH"
fi
echo

echo "🐳 Docker:"
if command -v docker >/dev/null 2>&1; then
    docker --version || echo "⚠️ تعذر قراءة نسخة docker"
else
    echo "ℹ️ Docker غير مثبت"
fi
echo

echo "🐍 Python:"
if command -v python3 >/dev/null 2>&1; then
    python3 --version || true
else
    echo "❌ python3 غير متوفر"
fi

if command -v pip3 >/dev/null 2>&1; then
    pip3 --version || true
else
    echo "ℹ️ pip3 غير متوفر على النظام"
fi
echo

# 2) إعداد البيئة الافتراضية (لا نثبت حزم كاملة إلا في وضع run)
echo "---- [2] venv داخل HyperFFactory ----"
if command -v python3 >/dev/null 2>&1; then
    if [ ! -d "${VENV_DIR}" ]; then
        echo "🔧 إنشاء venv جديد في ${VENV_DIR} ..."
        python3 -m venv "${VENV_DIR}"
        echo "✅ تم إنشاء venv"
    else
        echo "✅ venv موجود مسبقاً في ${VENV_DIR}"
    fi
else
    echo "❌ لا يمكن إنشاء venv بدون python3"
fi
echo

if [ -d "${VENV_DIR}" ]; then
    # تفعيل الـ venv مؤقتًا عند الحاجة
    # shellcheck disable=SC1090
    source "${VENV_DIR}/bin/activate"
    echo "🔓 venv مفعل: $(which python)"

    if [ "${MODE}" = "run" ]; then
        echo
        echo "---- [3] تثبيت المتطلبات داخل venv ----"
        if [ -f "${REQUIREMENTS}" ]; then
            echo "📦 تثبيت المتطلبات من ${REQUIREMENTS}"
            if ! pip install -r "${REQUIREMENTS}"; then
                echo "⚠️ حدث تعارض أو خطأ في ${REQUIREMENTS} → استخدام حزمة أساسية بديلة..."
                pip install fastapi uvicorn sqlalchemy pydantic requests python-dotenv || \
                    echo "⚠️ فشل التثبيت الأساسي أيضاً (تجاهُل وإكمال الفحص)..."
            fi
        else
            echo "📦 لا يوجد ${REQUIREMENTS} → تثبيت حزمة أساسية..."
            pip install fastapi uvicorn sqlalchemy pydantic requests python-dotenv || \
                echo "⚠️ فشل التثبيت الأساسي (تجاهُل وإكمال الفحص)..."
        fi
    else
        echo "ℹ️ MODE=check → لن يتم تثبيت حزم، فقط التحقق من venv."
    fi

    deactivate || true
else
    echo "ℹ️ لا يوجد venv فعال، تم تخطي تثبيت المتطلبات."
fi
echo

# 4) فحص/تشغيل Docker Stack
echo "---- [4] نظام Docker Stack (stack/core) ----"
COMPOSE_FILE="${BASE}/stack/core/docker-compose.core.yml"
DC_CMD="$(docker_compose_cmd)"

if [ -f "${COMPOSE_FILE}" ] && [ -n "${DC_CMD}" ]; then
    if [ "${MODE}" = "run" ]; then
        echo "🚀 تشغيل Docker Stack الأساسي..."
        # نستخدم الأمر المختار (docker compose أو docker-compose)
        if ! ${DC_CMD} -f "${COMPOSE_FILE}" up -d; then
            echo "⚠️ فشل تشغيل docker stack (up -d)، سيتم متابعة الفحص بدون إيقاف السكربت."
        fi

        echo
        echo "📊 حالة الخدمات (ps):"
        ${DC_CMD} -f "${COMPOSE_FILE}" ps || \
            echo "⚠️ تعذر قراءة حالة الخدمات."
    else
        echo "🔍 فحص تكوين Docker (config):"
        if ! ${DC_CMD} -f "${COMPOSE_FILE}" config; then
            echo "⚠️ docker config فشل، تحقق يدويًا من ${COMPOSE_FILE}"
        fi
    fi
else
    if [ ! -f "${COMPOSE_FILE}" ]; then
        echo "ℹ️ ملف compose غير موجود: ${COMPOSE_FILE}"
    fi
    if [ -z "${DC_CMD}" ]; then
        echo "ℹ️ لا يوجد docker compose أو docker-compose متاح على هذا النظام."
    fi
fi
echo

# 5) فحص الهيكل النهائي (ملفات كود فقط ملخص)
echo "---- [5] ملخص هيكل الكود (py / sh) ----"
echo "📁 عينات من ملفات الكود داخل HyperFFactory:"
find "${BASE}" -path "${BASE}/.git" -prune -o -type f \( -name "*.py" -o -name "*.sh" \) -print | head -20

CODE_FILES_COUNT=$(find "${BASE}" -path "${BASE}/.git" -prune -o -type f \( -name "*.py" -o -name "*.sh" \) -print | wc -l | tr -d ' ')
echo "... (إجمالي ${CODE_FILES_COUNT} ملف برمجي *.py/*.sh داخل HyperFFactory)"
echo

echo "✅ HyperFFactory enhanced bootstrap (${MODE}) finished."
