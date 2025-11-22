from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
import uvicorn
import os

app = FastAPI(
    title="SmartFriend Web UI",
    description="Web interface for SmartFriend Suite",
    version="1.0.0"
)

# Mount static files
static_dir = os.path.join(os.path.dirname(__file__), "static")
os.makedirs(static_dir, exist_ok=True)

@app.get("/")
async def serve_index():
    return {"service": "web", "status": "active", "message": "Web UI is running"}

@app.get("/health")
async def health():
    return {"status": "healthy", "service": "web"}

@app.get("/dashboard")
async def dashboard():
    return {"dashboard": "main", "status": "available"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8390)
