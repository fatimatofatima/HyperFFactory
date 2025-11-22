from fastapi import FastAPI
import uvicorn

app = FastAPI(
    title="SmartFriend Core API",
    description="Core business logic service",
    version="1.0.0"
)

@app.get("/")
async def root():
    return {"service": "core", "status": "active"}

@app.get("/health")
async def health():
    return {"status": "healthy", "service": "core"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8216)
