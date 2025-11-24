#!/bin/bash
# استعلام آمن مع retry
for i in {1..3}; do
    if sqlite3 "$1" "$2" 2>/dev/null; then
        break
    else
        sleep 0.1
    fi
done
