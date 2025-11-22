"""
SmartFriend Suite - Memory API (placeholder)

هذا التطبيق مؤقت لضمان عمل sf-memory.service
لحين ربطه بتطبيق الذاكرة الحقيقي.
"""

from fastapi import FastAPI

app = FastAPI(
    title="SmartFriend Memory API (placeholder)",
    version="0.1.0",
)

@app.get("/health", tags=["health"])
async def health():
    return {"status": "ok", "component": "memory-api", "mode": "placeholder"}

@app.get("/", tags=["root"])
async def root():
    return {
        "message": "SmartFriend Memory API placeholder is running.",
        "detail": "هذا endpoint مؤقت إلى أن يتم توصيله بمحرك الذاكرة الفعلي."
    }
