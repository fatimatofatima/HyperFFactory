#!/usr/bin/env bash
set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DATA_DIR="${ROOT_DIR}/ai/datasets"

mkdir -p "${DATA_DIR}"

OUT="${DATA_DIR}/train_backend.jsonl"

echo "[AI] Generating placeholder training dataset for Backend Junior → ${OUT}"

cat > "${OUT}" <<'EOF_TRAIN'
{"track_id":"backend_junior","phase_id":"phase1_python_core","skill_id":"python_syntax_basics","input":"اشرح لي المتغيرات في بايثون مع أمثلة بسيطة.","target":"شرح مبسط للمتغيرات في بايثون + كود."}
{"track_id":"backend_junior","phase_id":"phase3_backend_basics","skill_id":"rest_api_concepts","input":"ما هو REST API؟","target":"تعريف REST API مع توضيح مبادئه الأساسية."}
EOF_TRAIN

echo "[AI] Done. عدّل هذا الملف لاحقًا ببيانات حقيقية من logs أو أسئلة المستخدمين."
