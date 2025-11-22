#!/bin/bash

echo "🚀 تنظيم فوري لجميع سكريبتات sf_* المبعثرة..."

# إنشاء المجلدات إذا لم تكن موجودة
mkdir -p /root/HyperFFactory/scripts/{suites,services,core,maintenance,gateways,spiders,secrets,unification,reports,testing,agents}

# نقل سكريبتات suites
echo "📦 نقل سكريبتات suites..."
mv /root/HyperFFactory/sf_suite_*.sh /root/HyperFFactory/scripts/suites/ 2>/dev/null

# نقل سكريبتات services
echo "📦 نقل سكريبتات services..."
mv /root/HyperFFactory/sf_services_*.sh /root/HyperFFactory/scripts/services/ 2>/dev/null

# نقل سكريبتات system core
echo "📦 نقل سكريبتات system core..."
mv /root/HyperFFactory/sf_system_*.sh /root/HyperFFactory/scripts/core/ 2>/dev/null
mv /root/HyperFFactory/sf_smart_monitor.sh /root/HyperFFactory/scripts/core/ 2>/dev/null
mv /root/HyperFFactory/sf_safe_startup.sh /root/HyperFFactory/scripts/core/ 2>/dev/null

# نقل سكريبتات maintenance
echo "📦 نقل سكريبتات maintenance..."
mv /root/HyperFFactory/sf_*fix*.sh /root/HyperFFactory/scripts/maintenance/ 2>/dev/null
mv /root/HyperFFactory/sf_*repair*.sh /root/HyperFFactory/scripts/maintenance/ 2>/dev/null

# نقل سكريبتات gateways
echo "📦 نقل سكريبتات gateways..."
mv /root/HyperFFactory/sf_*gateway*.sh /root/HyperFFactory/scripts/gateways/ 2>/dev/null

# نقل سكريبتات spiders
echo "📦 نقل سكريبتات spiders..."
mv /root/HyperFFactory/sf_*spider*.sh /root/HyperFFactory/scripts/spiders/ 2>/dev/null

# نقل سكريبتات secrets
echo "📦 نقل سكريبتات secrets..."
mv /root/HyperFFactory/sf_*secret*.sh /root/HyperFFactory/scripts/secrets/ 2>/dev/null
mv /root/HyperFFactory/sf_*token*.sh /root/HyperFFactory/scripts/secrets/ 2>/dev/null

# نقل سكريبتات unification
echo "📦 نقل سكريبتات unification..."
mv /root/HyperFFactory/sf_*unif*.sh /root/HyperFFactory/scripts/unification/ 2>/dev/null

# نقل سكريبتات reports
echo "📦 نقل سكريبتات reports..."
mv /root/HyperFFactory/sf_*report*.sh /root/HyperFFactory/scripts/reports/ 2>/dev/null

# نقل سكريبتات testing
echo "📦 نقل سكريبتات testing..."
mv /root/HyperFFactory/sf_test_*.sh /root/HyperFFactory/scripts/testing/ 2>/dev/null

# نقل سكريبتات agents
echo "📦 نقل سكريبتات agents..."
mv /root/HyperFFactory/sf_*agent*.sh /root/HyperFFactory/scripts/agents/ 2>/dev/null

# نقل أي سكريبتات sf_ متبقية إلى core
echo "📦 نقل السكريبتات المتبقية..."
mv /root/HyperFFactory/sf_*.sh /root/HyperFFactory/scripts/core/ 2>/dev/null
mv /root/HyperFFactory/sf_*.py /root/HyperFFactory/scripts/core/ 2>/dev/null

echo "✅ اكتمل التنظيم الفوري!"
