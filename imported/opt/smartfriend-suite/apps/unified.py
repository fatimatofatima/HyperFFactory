#!/usr/bin/env python3
"""
SmartFriend Unified API Gateway (v0.1)

- نقطة دخول واحدة للسيوت على port 8220 (sf-unified.service).
- توفر health بسيط + status ملخّص عن الخدمات الداخلية.
"""

from __future__ import annotations

import os
from typing import Dict, Any

from fastapi import FastAPI
import httpx

app = FastAPI(
    title="SmartFriend Unified API",
    version="0.1.0",
    description="Unified gateway for SmartFriend Suite services.",
)

# عناوين الخدمات الداخلية (يمكن تعديلها عبر env إذا احتجت)
INTERNAL_SERVICES: Dict[str, str] = {
    "core": os.getenv("SF_CORE_URL", "http://127.0.0.1:8211"),
    "memory": os.getenv("SF_MEMORY_URL", "http://127.0.0.1:8214"),
    "health": os.getenv("SF_HEALTH_URL", "http://127.0.0.1:8215"),
    "web": os.getenv("SF_WEB_URL", "http://127.0.0.1:8390"),
}


@app.get("/health")
async def health() -> Dict[str, Any]:
    """
    فحص بسيط للخدمة الموحدة نفسها.
    """
    return {
        "service": "unified",
        "status": "ok",
    }


@app.get("/status")
async def status() -> Dict[str, Any]:
    """
    فحص حالة الخدمات الداخلية (core/memory/health/web).
    نحاول استدعاء /health لكل خدمة إذا كان موجودًا، أو GET على الجذر كحل بديل.
    """
    summary: Dict[str, Any] = {}
    timeout = httpx.Timeout(2.0, connect=2.0)

    async with httpx.AsyncClient(timeout=timeout) as client:
        for name, base_url in INTERNAL_SERVICES.items():
            entry: Dict[str, Any] = {"base_url": base_url}
            try:
                # نحاول /health أولاً
                url = f"{base_url.rstrip('/')}/health"
                resp = await client.get(url)
                entry["http_status"] = resp.status_code
                entry["ok"] = resp.status_code == 200
            except Exception as exc:
                # لو فشل /health نحاول GET على الجذر
                try:
                    url = base_url.rstrip("/")
                    resp = await client.get(url)
                    entry["http_status"] = resp.status_code
                    entry["ok"] = resp.status_code in (200, 404)
                    entry["note"] = "fallback root check"
                except Exception as exc2:
                    entry["ok"] = False
                    entry["error"] = str(exc2)
            summary[name] = entry

    return {
        "service": "unified",
        "status": "ok",
        "dependencies": summary,
    }
