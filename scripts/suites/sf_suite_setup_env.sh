#!/usr/bin/env bash
# Unified Environment Setup
set -Eeuo pipefail

ENV_FILE="/etc/smartfriend/sf_suite.env"
mkdir -p /etc/smartfriend

log() { echo "[$(date '+%F %T')] $*"; }

log "Setting up unified environment..."

cat > "$ENV_FILE" <<'CONFIG'
# SmartFriend Suite Unified Configuration
DB_PATH="/opt/smartfriend-suite/var/db/smartfriend_unified.db"
MEMORY_DB="/opt/smartfriend-suite/var/db/memory.db"
LOG_DIR="/opt/smartfriend-suite/var/log"

# API Ports
GATEWAY_PORT=8210
UNIFIED_PORT=8220
MEMORY_PORT=8214
CORE_PORT=8211
WEB_PORT=8390

# Telegram Bots (UPDATE WITH REAL TOKENS)
TELEGRAM_MAIN_TOKEN="YOUR_MAIN_BOT_TOKEN"
TELEGRAM_PROGRAMMER_TOKEN="YOUR_PROGRAMMER_BOT_TOKEN"

# Feature Flags
ENABLE_LEARNING=true
ENABLE_SPIDER=true
ENABLE_MEMORY=true
CONFIG

log "✅ Environment file created: $ENV_FILE"
