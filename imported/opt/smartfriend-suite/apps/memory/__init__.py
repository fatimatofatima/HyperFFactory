from fastapi import FastAPI

app = FastAPI(
    title="SmartFriend Memory API",
    description="واجهة الذاكرة لخدمات SmartFriend",
    version="1.0.0"
)

@app.get("/")
async def root():
    return {"message": "SmartFriend Memory API - نظام الذاكرة"}

@app.get("/health")
async def health():
    return {"status": "healthy", "service": "memory"}

@app.get("/recall")
async def recall(key: str = "default"):
    return {
        "key": key,
        "value": f"بيانات الذاكرة للمفتاح: {key}",
        "service": "memory"
    }
