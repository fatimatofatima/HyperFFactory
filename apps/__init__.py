"""
Applications module for HyperFFactory
"""
from fastapi import FastAPI
from pydantic import BaseModel

class HealthResponse(BaseModel):
    status: str
    version: str = "1.0.0"

def create_app():
    """Create FastAPI application"""
    return FastAPI(title="HyperFFactory API")
