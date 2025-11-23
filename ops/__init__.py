"""
Operations module for HyperFFactory
"""
import psutil
import os
import sys

def get_system_health():
    """Get system health metrics"""
    return {
        "cpu_percent": psutil.cpu_percent(),
        "memory_percent": psutil.virtual_memory().percent,
        "disk_usage": psutil.disk_usage('/').percent
    }

def monitor_services():
    """Monitor running services"""
    return {"status": "healthy", "services": []}
