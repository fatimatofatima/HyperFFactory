from fastapi import FastAPI
import uvicorn
import os

app = FastAPI(
    title="SmartFriend Unified API",
    description="Unified API gateway for all services",
    version="1.0.0"
)

@app.get("/")
async def root():
    return {"service": "unified", "status": "active", "version": "1.0.0"}

@app.get("/health")
async def health():
    return {"status": "healthy", "service": "unified"}

@app.get("/services")
async def list_services():
    services = [
        {"name": "memory", "port": 8214, "status": "active"},
        {"name": "web", "port": 8390, "status": "active"},
        {"name": "health", "port": 8215, "status": "active"},
        {"name": "unified", "port": 8220, "status": "active"}
    ]
    return {"services": services}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8220)
