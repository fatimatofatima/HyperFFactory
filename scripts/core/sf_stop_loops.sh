#!/usr/bin/env bash
set -Eeuo pipefail

echo "=================================================="
echo "  SmartFriend Suite - إيقاف لوب الخدمات المعطّلة"
echo "=================================================="

SERVICES=(
  sf-bot-programmer.service
  sf-spider.service
)

TIMERS=(
  sf-bot-programmer.timer
  sf-spider.timer
  smartfrind-guard.timer
)

echo
echo "⏹ إيقاف التايمرات المرتبطة وتعطيلها/إخفائها..."
for t in "${TIMERS[@]}"; do
  echo "  - Timer: ${t}"
  systemctl stop    "${t}" 2>/dev/null || true
  systemctl disable "${t}" 2>/dev/null || true
  systemctl mask    "${t}" 2>/dev/null || true
done

echo
echo "⏹ إيقاف الخدمات المستمرة في اللوب وتعطيلها/إخفائها..."
for svc in "${SERVICES[@]}"; do
  echo "  - Service: ${svc}"
  systemctl stop    "${svc}" 2>/dev/null || true
  systemctl disable "${svc}" 2>/dev/null || true
  systemctl mask    "${svc}" 2>/dev/null || true
done

echo
echo "🔄 reset failed units..."
systemctl reset-failed || true

echo
echo "📊 حالة الخدمات الآن (قد تظهر inactive/masked):"
systemctl status sf-bot-programmer.service sf-spider.service 2>/dev/null || true

echo
echo "✅ انتهى إيقاف اللوبات (الخدمات والـ timers الآن متوقفة ومخفية)."
