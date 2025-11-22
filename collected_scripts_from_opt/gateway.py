from fastapi import FastAPI, Request
import os, httpx

app = FastAPI(title="Factory Gateway", version="1.1")

@app.get("/health")
def health(): 
    return {"status":"ok","factory":"gw","version":"1.1"}

@app.post("/behavior/analyze")
async def behavior(req: Request):
    data = await req.json()
    return {
        "ok": True, 
        "engine": "behavioral", 
        "input": data,
        "result": {"score": 0.85, "risk": "low"}
    }

@app.post("/forensics/case")
async def case(req: Request):
    data = await req.json()
    return {
        "ok": True, 
        "engine": "forensic", 
        "input": data,
        "result": {"status": "processed", "case_id": data.get("case_id", "unknown")}
    }
