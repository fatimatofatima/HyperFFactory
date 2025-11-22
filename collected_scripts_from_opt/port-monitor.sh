#!/bin/bash
PORT=8170
if ! netstat -tln | grep -q ":${PORT} "; then
    echo "❌ البورت $PORT غير شغال - إعادة التشغيل"
    systemctl restart sf-factory
fi
