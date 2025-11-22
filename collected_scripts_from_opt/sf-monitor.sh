#!/usr/bin/env bash
set -e
while true; do
  clear
  echo "🔄 آخر تحديث: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "=========================================="
  
  echo "🌐 المنافذ النشطة:"
  ss -ltnp 2>/dev/null | grep -E ':(8210|8214|8220)' | while read line; do
    echo "  $line"
  done || echo "  لا توجد منافذ نشطة"
  
  echo ""
  echo "❤️  فحص الصحة:"
  for p in 8214 8220 8210; do
    printf "  :%-4s -> " "$p"
    if curl -fsS "http://127.0.0.1:$p/health" >/dev/null 2>&1; then
      echo "✅ UP"
    else
      echo "❌ DOWN"
    fi
  done
  
  echo ""
  echo "⚙️  حالة الخدمات:"
  services=("sf-memory" "sf-unified" "sf-health" "sf-smartfrind" "sf-smartfactory")
  for service in "${services[@]}"; do
    status=$(systemctl is-active "$service.service" 2>/dev/null || echo "غير موجود")
    if [ "$status" = "active" ]; then
      echo "  ✅ $service: نشط"
    elif [ "$status" = "inactive" ]; then
      echo "  ⏸️  $service: متوقف"
    else
      echo "  ❌ $service: $status"
    fi
  done
  
  echo ""
  echo "📊 استخدام الموارد:"
  ps aux --sort=-%mem | head -n 5 | awk '{print $2, $11}' | while read pid cmd; do
    if [[ ! -z "$pid" && "$pid" != "PID" ]]; then
      mem=$(ps -p $pid -o %mem --no-headers 2>/dev/null || echo "0")
      cpu=$(ps -p $pid -o %cpu --no-headers 2>/dev/null || echo "0")
      echo "  PID $pid: $cmd (CPU: ${cpu}%, MEM: ${mem}%)"
    fi
  done
  
  sleep 5
done
