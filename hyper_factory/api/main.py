from fastapi import FastAPI
from pydantic import BaseModel
from datetime import datetime
from pathlib import Path

# جذر المشروع: /root/HyperFFactory (ثابت حسب موقع الملف الحالي)
BASE_DIR = Path(__file__).resolve().parents[3]


app = FastAPI(
    title="HyperFFactory Core API",
    version="0.1.0",
    description="Unified API gateway for HyperFFactory (local runtime).",
)


class HealthResponse(BaseModel):
    status: str
    time: str
    base_dir: str
    notes: str | None = None


@app.get("/health", response_model=HealthResponse)
def health_check() -> HealthResponse:
    """فحص صحة نواة HyperFFactory"""
    return HealthResponse(
        status="ok",
        time=datetime.utcnow().isoformat() + "Z",
        base_dir=str(BASE_DIR),
        notes="HyperFFactory core API healthy",
    )
