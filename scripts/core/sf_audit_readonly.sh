#!/usr/bin/env bash
set -Eeuo pipefail
echo "SmartFriend Suite - Audit $(date -Is)"
echo "== System =="; (lsb_release -d 2>/dev/null || grep PRETTY_NAME /etc/os-release) | sed 's/.*=//'; df -h /; free -h; uptime
echo "== Identity =="; grep -vE 'KEY|TOKEN' /opt/smartfriend-suite/ENV/identity.conf 2>/dev/null || echo "missing identity"
echo "== Services =="; for s in sf-bot-assistant sf-bot-programmer sf-bot-behavior; do echo "-- $s --"; systemctl is-enabled $s 2>/dev/null || true; systemctl is-active $s 2>/dev/null || true; done
echo "== Ports =="; ss -ltnp | egrep ':8210|:8212|:8214|:8220|:8383' || true
echo "== Health =="; for p in 8210 8212 8214 8220; do echo -n "http://127.0.0.1:$p/health -> "; curl -fsS "http://127.0.0.1:$p/health" || echo "no"; done
echo "== DB =="; ls -lh /opt/smartfriend-suite/data/*.db 2>/dev/null || true
