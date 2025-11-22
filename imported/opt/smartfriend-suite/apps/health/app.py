from fastapi import FastAPI
import uvicorn
import psutil
import os

app = FastAPI(
    title="SmartFriend Health API",
    description="Health monitoring service",
    version="1.0.0"
)

@app.get("/")
async def root():
    return {"service": "health", "status": "active"}

@app.get("/health")
async def health_check():
    cpu_percent = psutil.cpu_percent(interval=0.1)
    memory = psutil.virtual_memory()
    disk = psutil.disk_usage('/')
    
    return {
        "status": "healthy",
        "service": "health",
        "system": {
            "cpu_percent": cpu_percent,
            "memory_percent": memory.percent,
            "disk_percent": disk.percent
        }
    }

@app.get("/status")
async def system_status():
    services = ["memory", "web", "health", "unified"]
    return {
        "services": services,
        "total": len(services),
        "status": "operational"
    }

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8215)
