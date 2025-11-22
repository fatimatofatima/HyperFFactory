#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

# ==========================================
# 🎯 SmartFriend Stack - Full Deployment
# ==========================================

DOMAIN="${1:-62.171.172.105}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $*"; }

echo "=========================================="
echo "   🎯 SmartFriend Stack - Full Deployment"
echo "=========================================="
echo

log "🚀 المرحلة 1: نشر/تحديث الكود..."
/root/sf_publish_all.sh

echo
log "🌐 المرحلة 2: إعداد Nginx Gateway..."
/root/sf_nginx_smartstack.sh "$DOMAIN"

echo
log "📊 المرحلة 3: فحص الحالة النهائية..."
smartfriend status

echo
echo "=========================================="
echo "   ✅ النشر الكامل اكتمل!"
echo "=========================================="
echo "• Dashboard    : http://${DOMAIN}/"
echo "• Smart Core   : http://${DOMAIN}/core/"
echo "• Unified API  : http://${DOMAIN}/unified/"
echo "• Gateway      : http://${DOMAIN}/gateway/"
echo
echo "🎯 الأوامر اليومية:"
echo "  smartfriend status    - حالة الخدمات"
echo "  /root/sf_publish_all.sh - تحديث الكود"
echo "=========================================="
