from fastapi import FastAPI
import time
import socket
import os

app = FastAPI(
    title="SmartFriend Suite Health",
    version="1.0.0",
)

@app.get("/health")
async def health():
    return {
        "service": "sf-health",
        "status": "ok",
        "hostname": socket.gethostname(),
        "env": os.getenv("SF_ENV", "unknown"),
        "time": time.strftime("%Y-%m-%d %H:%M:%S"),
    }
