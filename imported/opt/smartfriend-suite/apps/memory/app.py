from fastapi import FastAPI
app = FastAPI(title="SmartFriend Memory API")
@app.get("/")
async def root(): return {"message": "SmartFriend Memory API"}
@app.get("/health")
async def health(): return {"status": "healthy"}
