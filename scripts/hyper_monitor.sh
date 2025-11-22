#!/bin/bash
# نظام مراقبة HyperFactory الدائم
while true; do
    ./scripts/hyper_brain_controller.sh dashboard
    sleep 30
done
