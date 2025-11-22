from fastapi import FastAPI
import uvicorn
import os

app = FastAPI(
    title="SmartFriend Memory API",
    description="Memory management service",
    version="1.0.0"
)

@app.get("/")
async def root():
    return {"service": "memory", "status": "active"}

@app.get("/health")
async def health():
    return {"status": "healthy", "service": "memory"}

@app.get("/memory")
async def get_memory():
    return {"memories": [], "count": 0}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8214)
