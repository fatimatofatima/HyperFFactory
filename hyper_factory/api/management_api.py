from datetime import datetime
from typing import Dict, Any, List

from fastapi import APIRouter, HTTPException

from hyper_factory.management.brain.central_brain import CentralManagementBrain
from hyper_factory.management.managers.operations_manager import OperationsManager
from hyper_factory.management.managers.quality_manager import QualityManager


router = APIRouter(prefix="/management", tags=["Management"])

brain = CentralManagementBrain()
ops_manager = OperationsManager()
quality_manager = QualityManager()


@router.get("/strategic-plan")
async def get_strategic_plan() -> Dict[str, Any]:
    """الخطة الاستراتيجية"""
    try:
        plan = brain.strategic_planning()
        return {"status": "success", "data": plan}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.post("/production-plan")
async def create_production_plan(orders: List[Dict[str, Any]]) -> Dict[str, Any]:
    """خطة إنتاجية"""
    try:
        plan = ops_manager.create_production_plan(orders)
        return {"status": "success", "data": plan}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.get("/operations-status")
async def get_operations_status() -> Dict[str, Any]:
    """حالة العمليات"""
    try:
        status = ops_manager.monitor_operations()
        return {"status": "success", "data": status}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.post("/quality-check")
async def perform_quality_check(product_data: Dict[str, Any]) -> Dict[str, Any]:
    """فحص جودة"""
    try:
        result = quality_manager.perform_quality_check(product_data)
        return {"status": "success", "data": result}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.get("/quality-report")
async def get_quality_report() -> Dict[str, Any]:
    """تقرير الجودة"""
    try:
        report = quality_manager.get_quality_report()
        return {"status": "success", "data": report}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.get("/health")
async def management_health() -> Dict[str, Any]:
    """Health check لنظام الإدارة"""
    return {
        "status": "healthy",
        "service": "Management System",
        "timestamp": datetime.now().isoformat(),
        "components": {
            "central_brain": "active",
            "operations_manager": "active",
            "quality_manager": "active",
        },
    }
