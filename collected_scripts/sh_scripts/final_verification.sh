#!/bin/bash

echo "=== التحقق النهائي من النظام ==="

echo "1. واجهات المعرفة:"
sqlite3 /opt/hyper-factory/var/db/knowledge/knowledge_main.db "
SELECT name FROM sqlite_master WHERE type='view' AND name LIKE 'v_knowledge%';
"

echo "2. واجهات الذاكرة:"
sqlite3 /opt/hyper-factory/var/db/memory/memory_core_2025.db "
SELECT name FROM sqlite_master WHERE type='view' AND name LIKE 'v_legacy%';
"

echo "3. حجم قواعد البيانات:"
du -h /opt/hyper-factory/var/db/knowledge/knowledge_main.db
du -h /opt/hyper-factory/var/db/memory/memory_core_2025.db
du -h /opt/hyper-factory/var/db/identity/identity.db

echo "4. ملخص البيانات:"
echo "المعرفة:"
sqlite3 /opt/hyper-factory/var/db/knowledge/knowledge_main.db "SELECT COUNT(*) FROM documents;"

echo "الذاكرة:"
sqlite3 /opt/hyper-factory/var/db/memory/memory_core_2025.db "SELECT COUNT(*) FROM events;"

echo "الهوية:"
sqlite3 /opt/hyper-factory/var/db/identity/identity.db "SELECT COUNT(*) FROM entities;"
