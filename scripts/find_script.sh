#!/bin/bash
echo "🔍 البحث عن: $1"
find /root/HyperFFactory/scripts -name "*$1*" -type f | head -10
