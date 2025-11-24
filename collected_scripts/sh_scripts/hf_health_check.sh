#!/bin/bash
echo "🏥 فحص صحة Hyper Factory"

# فحص المسارات
echo "📁 فحص المسارات..."
ls -la /root/hyper-factory* 2>/dev/null

# فحص قواعد البيانات
echo "🗃️ فحص قواعد البيانات..."
find /root/hyper-factory -name "*.db" -type f 2>/dev/null | head -10

# فحص المساحة
echo "💾 فحص المساحة..."
df -h /root

# فحص الذاكرة
echo "🧠 فحص الذاكرة..."
free -h

# فحص السكربتات
echo "🔧 فحص السكربتات..."
find /root -name "hf_*.sh" -type f | head -10
