#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

# ================================
# SmartFriend Suite – Unified Migration (G1–G10 + Disk + G10)
# ================================

TS="$(date '+%Y%m%d_%H%M%S')"
REPORT_DIR="/opt/smartfriend-suite/reports"
ARCHIVE_ROOT="/opt/smartfriend-suite/archive"
mkdir -p "$REPORT_DIR" "$ARCHIVE_ROOT"

MAIN_REPORT="${REPORT_DIR}/sf_suite_unified_migration_${TS}.log"

MIN_FREE_GB=10      # الحد الأدنى للمساحة الحرة
MAX_USE_PCT=90      # أقصى نسبة استخدام
ROOT_FS="/"
DISK_STATUS="unknown"

log() {
    echo "[$(date '+%F %T')] $*" | tee -a "$MAIN_REPORT"
}

require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "❌ هذا السكربت يجب أن يعمل بصلاحيات root." >&2
        exit 1
    fi
}

check_disk() {
    local line total_kb free_kb use_pct_str use_pct free_gb
    line=$(df -Pk "$ROOT_FS" | awk 'NR==2 {print $2, $4, $5}')
    read -r total_kb free_kb use_pct_str <<<"$line"
    use_pct="${use_pct_str%%%}"
    free_gb=$(( free_kb / 1024 / 1024 ))

    log "📊 فحص القرص على $ROOT_FS: الاستخدام=${use_pct}% | المساحة الحرة=${free_gb}GB"

    if [ "$free_gb" -lt "$MIN_FREE_GB" ] || [ "$use_pct" -gt "$MAX_USE_PCT" ]; then
        log "⚠️ حالة القرص: LOW SPACE (free<${MIN_FREE_GB}GB أو use>${MAX_USE_PCT}%)"
        DISK_STATUS="low"
    else
        log "✅ حالة القرص: OK"
        DISK_STATUS="ok"
    fi
}

# ================================
# G10 – تنظيف وحدات legacy (smartfrind-* / smartfriend-*)
# ================================
g10_cleanup_legacy_units() {
    local LEGACY_REPORT="${ARCHIVE_ROOT}/systemd_legacy_units_${TS}.csv"
    mkdir -p "$ARCHIVE_ROOT"

    log "🔄 G10: بدء تنظيف وحدات systemd القديمة (smartfrind-* / smartfriend-*)."
    echo "unit,state,enabled_before,active_before" > "$LEGACY_REPORT"

    local patterns=("smartfrind-*" "smartfriend-*")
    for pattern in "${patterns[@]}"; do
        while read -r unit state; do
            [ -z "$unit" ] && continue

            case "$unit" in
                sf-*|ffactory-*|docker-* )
                    # لا نلمس sf-* ولا ffactory-* ولا docker-*
                    continue
                    ;;
            esac

            local enabled_before active_before
            enabled_before=$(systemctl is-enabled "$unit" 2>/dev/null || echo "unknown")
            active_before=$(systemctl is-active "$unit" 2>/dev/null || echo "unknown")

            echo "$unit,$state,$enabled_before,$active_before" >> "$LEGACY_REPORT"

            log "🗑️ G10: إيقاف وتعطيل وحدة legacy: $unit (enabled=$enabled_before, active=$active_before)"
            systemctl stop "$unit" >/dev/null 2>&1 || true
            systemctl disable "$unit" >/dev/null 2>&1 || true

        done < <(systemctl list-unit-files "$pattern" --no-legend 2>/dev/null || true)
    done

    log "✅ G10: اكتمل تنظيف وحدات legacy. التقرير: $LEGACY_REPORT"
}

# ================================
# Step 1: Service Matrix Analysis
# ================================
generate_service_matrix() {
    local matrix_file="${REPORT_DIR}/service_matrix_${TS}.yaml"

    log "🔍 Step 1: Generating Service Matrix..."

    {
        echo "# SmartFriend Suite - Unified Service Matrix"
        echo "generated: $(date -Iseconds)"
        echo "hostname: $(hostname)"
        echo
        echo "services:"
        systemctl list-units 'sf-*' 'smartfrind-*' --all --no-legend 2>/dev/null | awk '{print $1}' | sort -u | while read -r service; do
            [ -z "$service" ] && continue
            status=$(systemctl is-active "$service" 2>/dev/null || echo "unknown")
            enabled=$(systemctl is-enabled "$service" 2>/dev/null || echo "unknown")
            family="sf"
            [[ "$service" == smartfrind-* ]] && family="legacy"

            type="other"
            [[ "$service" =~ gateway|api|unified ]] && type="api"
            [[ "$service" =~ memory ]] && type="memory"
            [[ "$service" =~ brain|learn|ingest|kb|train|harvest ]] && type="brain"
            [[ "$service" =~ spider|crawl ]] && type="spider"
            [[ "$service" =~ bot|telegram ]] && type="bot"
            [[ "$service" =~ health|watchdog|guard|monitor ]] && type="health"
            [[ "$service" =~ web|ui|dashboard ]] && type="web"

            echo "  - name: $service"
            echo "    family: $family"
            echo "    type: $type"
            echo "    status: $status"
            echo "    enabled: $enabled"
        done

        echo
        echo "# Critical Gaps Identified:"
        echo "gaps:"
        echo "  G1: 'Brand duplication - sf-* vs smartfrind-*'"
        echo "  G2: 'Port ownership conflict (8210/8211/8220)'"
        echo "  G3: 'Memory API gap (port 8214 dead)'"
        echo "  G4: 'Web UI dashboard missing'"
        echo "  G5: 'Brain/Learning system duplication'"
        echo "  G6: 'Spider/Harvester conflict'"
        echo "  G7: 'Bots identity crisis'"
        echo "  G8: 'Health/Guard system split'"
        echo "  G9: 'Secrets/Env management chaos'"
        echo "  G10: 'Legacy units accumulation'"
    } > "$matrix_file"

    log "✅ Service Matrix saved: $matrix_file"
    echo "$matrix_file"
}

# ================================
# Step 2: Target Architecture Design
# ================================
create_target_design() {
    local design_file="${REPORT_DIR}/target_architecture_${TS}.md"

    log "🎯 Step 2: Creating Target Architecture Design..."

    cat > "$design_file" <<'DESIGN_EOF'
# SmartFriend Suite - Target Architecture Design

## 🎯 Business Goal
Single unified platform: **SmartFriend Suite only** (no operational dependency on smartfrind-*), while keeping ffactory stack as-is.

## 📋 Service Catalog

### Core APIs & Gateways
| Service     | Port | Role               | Status        |
|-------------|------|--------------------|---------------|
| sf-gateway  | 8210 | Main Ask Gateway   | TO-BE-CREATED |
| sf-unified  | 8220 | Unified API        | TO-BE-CREATED |
| sf-memory   | 8214 | Memory API         | FIX-EXISTING  |
| sf-core     | 8211 | Core Logic/Internal| TO-BE-CREATED |

### Brain & Intelligence
| Service     | Role               | Action        |
|-------------|--------------------|---------------|
| sf-brain    | Main Brain         | CREATE-NEW    |
| sf-spider   | Web Harvester      | FIX-EXISTING  |
| sf-learning | Training Engine    | CREATE-NEW    |

### Bots & Interfaces
| Service             | Role                   | Action        |
|---------------------|------------------------|---------------|
| sf-bot              | Primary Telegram Bot   | FIX-EXISTING  |
| sf-bot-programmer   | Developer Bot          | FIX-EXISTING  |
| sf-web              | Web UI (8390)          | FIX-EXISTING  |

### Operations
| Service    | Role                | Action        |
|------------|---------------------|---------------|
| sf-health  | Health Monitoring   | FIX-EXISTING  |
| sf-guard   | Space/Resource Guard| CREATE-NEW    |

## 🔄 Migration Strategy

### Phase 1: Foundation
1. Create unified env: `/etc/smartfriend/sf_suite.env`
2. Fix critical services: `sf-memory`, `sf-web`, `sf-health`
3. Establish core APIs under sf-* on ports 8210/8211/8220

### Phase 2: Brain Unification
1. Migrate smartfrind-* logic into `sf-brain` / `sf-learning`
2. Stabilize `sf-spider` with harvest capabilities
3. Unify learning/KB/FTS pipeline under suite

### Phase 3: Bots & UI
1. Single Telegram bot stack (`sf-bot`, `sf-telegram-audit`)
2. Operational dashboard via `sf-web`
3. Nginx routing cleanup to point to sf-* only

### Phase 4: Cleanup
1. Archive legacy systemd units (smartfrind-* / smartfriend-*) – code/DB preserved
2. Remove legacy routes from Nginx
3. Final validation and health checks on ports 8210/8211/8214/8220/8390
DESIGN_EOF

    log "✅ Target Design saved: $design_file"
    echo "$design_file"
}

# ================================
# Step 3: Execution Runbooks
# ================================
generate_runbooks() {
    log "🛠️ Step 3: Generating Execution Runbooks..."

    # Runbook 1: Environment Setup
    cat > /root/sf_suite_setup_env.sh <<'ENV_EOF'
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
ENV_EOF

    chmod +x /root/sf_suite_setup_env.sh

    # Runbook 2: Service Promotion
    cat > /root/sf_suite_promote_services.sh <<'PROMOTE_EOF'
#!/usr/bin/env bash
# Promote SF-* Services to Production
set -Eeuo pipefail

if [ -f /etc/smartfriend/sf_suite.env ]; then
    source /etc/smartfriend/sf_suite.env
fi

log() { echo "[$(date '+%F %T')] $*"; }

FAILED_SERVICES=()

CORE_SERVICES=(
    "sf-memory.service"
    "sf-web.service"
    "sf-health.service"
    "sf-spider.service"
    "sf-bot.service"
    "sf-bot-programmer.service"
    "sf-telegram-audit.service"
)

log "Promoting SmartFriend Suite services..."

for service in "${CORE_SERVICES[@]}"; do
    if systemctl list-unit-files "$service" --no-legend >/dev/null 2>&1; then
        log "🔄 Enable & restart $service..."
        systemctl enable "$service" >/dev/null 2>&1 || log "⚠️ failed to enable $service"
        if systemctl restart "$service"; then
            log "✅ $service started successfully"
        else
            log "❌ Failed to start $service"
            FAILED_SERVICES+=("$service")
        fi
    else
        log "⚠️ $service not found as systemd unit - skipping"
    fi
done

if [ ${#FAILED_SERVICES[@]} -eq 0 ]; then
    log "🎉 All core services promoted successfully!"
else
    log "❌ Some services failed: ${FAILED_SERVICES[*]}"
    exit 1
fi
PROMOTE_EOF

    chmod +x /root/sf_suite_promote_services.sh

    log "✅ Runbooks generated in /root/"
}

# ================================
# Step 4: Final Migration Plan
# ================================
create_migration_plan() {
    local matrix_file="${1}"
    local design_file="${2}"
    local plan_file="${REPORT_DIR}/migration_plan_${TS}.md"

    log "📋 Step 4: Creating Final Migration Plan..."

    cat > "$plan_file" <<PLAN_EOF
# 🚀 SmartFriend Suite Unified Migration Plan

## 1. Context

- Goal: **SmartFriend Suite** becomes the **only official platform** with **no operational dependency** on smartfrind-*
- ffactory stack remains as-is
- Gaps addressed: G1–G10

Artifacts generated:
- Service Matrix: \`$matrix_file\`
- Target Architecture Design: \`$design_file\`
- Runbooks: \`/root/sf_suite_setup_env.sh\`, \`/root/sf_suite_promote_services.sh\`

## 2. Immediate Actions (Today)

### 2.1 Environment Setup
\`\`\`bash
sudo bash /root/sf_suite_setup_env.sh
\`\`\`

### 2.2 Service Promotion
\`\`\`bash
sudo bash /root/sf_suite_promote_services.sh
\`\`\`

### 2.3 Validation Check
\`\`\`bash
systemctl status sf-memory sf-web sf-health
ss -tlnp | grep -E ':(8210|8211|8214|8220|8390)'
\`\`\`

## 3. Success Metrics

- All ports (8210, 8211, 8214, 8220, 8390) served by sf-* only
- No \`smartfrind-*\` services in production
- Full functionality maintained
- **ffactory untouched and operational**

*Generated on: $(date)*
PLAN_EOF

    log "✅ Migration Plan saved: $plan_file"
    echo "$plan_file"
}

# ================================
# Main Execution
# ================================
main() {
    log "🚀 Starting SmartFriend Suite Unified Migration Process"
    require_root
    
    # فحص المساحة أولاً
    log "📊 Checking disk space..."
    check_disk
    
    if [[ "$DISK_STATUS" == "low" ]]; then
        log "⚠️ Low disk space detected - running G10 cleanup first..."
        g10_cleanup_legacy_units
        check_disk
    fi
    
    log "📊 Phase 1: Service Matrix Analysis"
    local matrix_file
    matrix_file=$(generate_service_matrix)
    
    log "🎯 Phase 2: Target Architecture Design"
    local design_file
    design_file=$(create_target_design)
    
    log "🛠️ Phase 3: Runbook Generation"
    generate_runbooks
    
    log "📋 Phase 4: Migration Planning"
    local plan_file
    plan_file=$(create_migration_plan "$matrix_file" "$design_file")
    
    log "🎉 Unified Migration Preparation Complete!"
    log ""
    log "📁 Generated Files:"
    log "   Service Matrix: $matrix_file"
    log "   Target Design: $design_file"
    log "   Migration Plan: $plan_file"
    log "   Runbooks: /root/sf_suite_setup_env.sh"
    log "             /root/sf_suite_promote_services.sh"
    log ""
    log "👉 Next Steps:"
    log "   1. Review the generated files"
    log "   2. Run: /root/sf_suite_setup_env.sh"
    log "   3. Run: /root/sf_suite_promote_services.sh"
    log "   4. Validate services and ports"
    log ""
    log "💡 Disk Status: $DISK_STATUS"
    log "📝 Main Report: $MAIN_REPORT"
}

main "$@"
