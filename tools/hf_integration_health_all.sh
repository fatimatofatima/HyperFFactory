#!/usr/bin/env bash
# HyperFFactory – Integration Health (SmartFriend + FFactory)

set -euo pipefail

ROOT="${ROOT:-/root/HyperFFactory}"
cd "$ROOT"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$ROOT/bin"

# shellcheck source=/dev/null
source "$BIN_DIR/hf_common.sh"

mkdir -p "$(dirname "$HF_QUALITY_DB")" "$(dirname "$HF_ERRORS_DB")" logs

SMARTFRIEND_SERVICE="${SMARTFRIEND_SERVICE:-sf-core.service}"
FFACTORY_DOCKER_PREFIX="${FFACTORY_DOCKER_PREFIX:-ffactory_}"

now_ts() {
  date '+%Y-%m-%d %H:%M:%S'
}

insert_quality() {
  local actor="$1"
  local check_name="$2"
  local result="$3"
  local score="$4"
  local details="$5"
  local scope="$6"
  local check_key="$7"
  local target="$8"
  local ts
  ts="$(now_ts)"

  sqlite3 "$HF_QUALITY_DB" <<SQL
INSERT INTO quality_checks (
  actor, check_name, result, score,
  details, tags, ts, scope, check_key, target, created_at
) VALUES (
  '$actor',
  '$check_name',
  '$result',
  $score,
  '$details',
  '[integration]',
  '$ts',
  '$scope',
  '$check_key',
  '$target',
  '$ts'
);
SQL
}

insert_error() {
  local actor="$1"
  local error_type="$2"
  local error_message="$3"
  local severity="$4"
  local scope="$5"
  local ts
  ts="$(now_ts)"

  sqlite3 "$HF_ERRORS_DB" <<SQL
INSERT INTO errors (
  actor, error_type, error_message, severity,
  context, tags, ts, state, resolved_at, task_id, scope
) VALUES (
  '$actor',
  '$error_type',
  '$error_message',
  '$severity',
  'hf_integration_health_all.sh',
  '[integration]',
  '$ts',
  'OPEN',
  NULL,
  NULL,
  '$scope'
);
SQL
}

check_smartfriend() {
  local state result score details severity

  state="$(systemctl is-active "$SMARTFRIEND_SERVICE" 2>/dev/null || true)"

  case "$state" in
    active)
      result="PASS"
      score=100
      details="$SMARTFRIEND_SERVICE active"
      severity=""
      ;;
    activating)
      result="WARN"
      score=60
      details="$SMARTFRIEND_SERVICE activating"
      severity="MEDIUM"
      ;;
    *)
      result="FAIL"
      score=0
      details="$SMARTFRIEND_SERVICE not active"
      severity="HIGH"
      ;;
  esac

  echo "SMARTFRIEND_RESULT=$result"
  echo "SMARTFRIEND_SCORE=$score"
  echo "SMARTFRIEND_DETAILS=$details"

  insert_quality \
    "hf_health_all" \
    "integration_smartfriend" \
    "$result" \
    "$score" \
    "$details" \
    "smartfriend" \
    "integration:smartfriend_health" \
    "smartfriend"

  if [[ "$result" != "PASS" ]]; then
    insert_error \
      "hf_health_all" \
      "integration_check" \
      "$details" \
      "$severity" \
      "smartfriend"
  fi
}

check_ffactory() {
  local result score details severity

  if ! command -v docker >/dev/null 2>&1; then
    result="WARN"
    score=50
    details="docker not found for ffactory check"
    severity="MEDIUM"
  else
    if docker ps --format '{{.Names}}' | grep -q "^${FFACTORY_DOCKER_PREFIX}"; then
      result="PASS"
      score=100
      details="ffactory containers running"
      severity=""
    else
      result="FAIL"
      score=0
      details="no ffactory containers running"
      severity="HIGH"
    fi
  fi

  echo "FFACTORY_RESULT=$result"
  echo "FFACTORY_SCORE=$score"
  echo "FFACTORY_DETAILS=$details"

  insert_quality \
    "hf_health_all" \
    "integration_ffactory" \
    "$result" \
    "$score" \
    "$details" \
    "ffactory" \
    "integration:ffactory_health" \
    "ffactory"

  if [[ "$result" != "PASS" ]]; then
    insert_error \
      "hf_health_all" \
      "integration_check" \
      "$details" \
      "$severity" \
      "ffactory"
  fi
}

echo "====================================================="
echo " HyperFFactory – Integration Health (SmartFriend + FFactory)"
echo " ROOT : $ROOT"
echo " TIME : $(now_ts)"
echo "====================================================="

ANY_FAIL=0

echo
echo "[1] SmartFriend Suite integration..."
check_smartfriend | tee logs/hf_integration_health_smartfriend.log
if grep -q "SMARTFRIEND_RESULT=FAIL" logs/hf_integration_health_smartfriend.log; then
  ANY_FAIL=1
fi

echo
echo "[2] FFactory Stack integration..."
check_ffactory | tee logs/hf_integration_health_ffactory.log
if grep -q "FFACTORY_RESULT=FAIL" logs/hf_integration_health_ffactory.log; then
  ANY_FAIL=1
fi

echo
echo "====================================================="
echo " Integration Health – summary"
echo "====================================================="

echo "SmartFriend:"
grep "^SMARTFRIEND_" logs/hf_integration_health_smartfriend.log || true

echo
echo "FFactory:"
grep "^FFACTORY_" logs/hf_integration_health_ffactory.log || true

# محاولة تحديث حالة المهام (لو السكربت موجود)
if [[ -x "$BIN_DIR/hf_tasks_admin.sh" ]]; then
  echo
  echo "[Tasks] حاول تحديث مهام التكامل (80 و 81) إلى DONE..."
  "$BIN_DIR/hf_tasks_admin.sh" set-status 80 DONE "integration_smartfriend_health run" || true
  "$BIN_DIR/hf_tasks_admin.sh" set-status 81 DONE "integration_ffactory_health run" || true
fi

if [[ "$ANY_FAIL" -ne 0 ]]; then
  echo
  echo "[RESULT] Integration health finished with failures."
  exit 1
fi

echo
echo "[RESULT] Integration health OK (no FAIL)."
exit 0
