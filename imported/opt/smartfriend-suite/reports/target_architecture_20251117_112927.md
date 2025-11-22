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
