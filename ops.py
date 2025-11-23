"""
HyperFactory Operations Module
"""
import psutil
import os
import sys

def get_system_health():
    return {
        "cpu_percent": psutil.cpu_percent(),
        "memory_percent": psutil.virtual_memory().percent,
        "disk_usage": psutil.disk_usage('/').percent
    }

def monitor_services():
    return {"status": "operational", "services": ["hyper_brain", "hyper_ai"]}
