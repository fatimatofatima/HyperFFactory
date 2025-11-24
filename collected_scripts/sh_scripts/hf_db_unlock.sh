#!/bin/bash
echo "🔓 فتح قفل قاعدة البيانات..."
fuser -k /root/hyper-factory/data/factory/factory.db
fuser -k /root/hyper-factory/data/knowledge/knowledge.db
rm -f /root/hyper-factory/data/factory/factory.db-journal
rm -f /root/hyper-factory/data/knowledge/knowledge.db-journal
echo "✅ تم فتح القفل"
