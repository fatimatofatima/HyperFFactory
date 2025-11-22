from fastapi import FastAPI

app = FastAPI(title="QA Sidecar")

@app.get("/")
async def root():
    return {"status": "QA Sidecar is working"}

@app.get("/health")
async def health():
    return {"status": "healthy"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8212)
