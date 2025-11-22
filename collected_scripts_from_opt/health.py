from fastapi import FastAPI

app = FastAPI(title="SmartFriend Health API")

@app.get("/")
async def root():
    return {"message": "SmartFriend Health API", "status": "running"}

@app.get("/health")
async def health_check():
    return {
        "status": "healthy", 
        "services": {
            "core": "up", 
            "memory": "up", 
            "unified": "up",
            "web": "up"
        }
    }
