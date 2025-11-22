# SmartFriend Suite - Target Architecture

## البورتات والخدمات
- 8210: Legacy Gateway → Future: sf-unified (8220)
- 8211: Core API (sf-core.service) 
- 8214: Memory API (sf-memory.service) - مستقبلي
- 8383: Core API Alternative
- 8390: Web UI (sf-web.service)

## مسارات Nginx
- `/ffactory/` → http://127.0.0.1:8210/
- `/unified/` → http://127.0.0.1:8210/ (مستقبلاً: 8220)
- `/core/` → http://127.0.0.1:8211/
- `/memory/` → http://127.0.0.1:8214/ (معلق)

## العائلات
- **sf-suite**: الخدمات الحديثة (sf-*)
- **smartfriend-legacy**: الوراثة (مجمدة)
- **ffactory**: النظام المنفصل
