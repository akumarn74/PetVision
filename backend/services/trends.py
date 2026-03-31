from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_
from backend.models.domain import PetScanResult
import uuid
from datetime import datetime, timedelta

async def calculate_30_day_trends(db: AsyncSession, pet_id: uuid.UUID) -> dict:
    """
    Calculates the 30-day moving average for health metrics and compares it 
    with the most recent scan to determine percentage changes (trends).
    """
    thirty_days_ago = datetime.utcnow() - timedelta(days=30)
    
    # 1. Get the most recent scan
    recent_query = select(PetScanResult).where(
        PetScanResult.pet_id == pet_id
    ).order_by(PetScanResult.timestamp.desc()).limit(1)
    
    result = await db.execute(recent_query)
    latest_scan = result.scalar_one_or_none()
    
    if not latest_scan:
        return {"status": "insufficient_data", "message": "No scans found for this pet."}
    
    # 2. Calculate averages over the last 30 days
    avg_query = select(
        func.avg(PetScanResult.body_condition_score).label('avg_body'),
        func.avg(PetScanResult.coat_health_score).label('avg_coat'),
        func.avg(PetScanResult.eye_clarity_score).label('avg_eye'),
        func.avg(PetScanResult.dental_plaque_score).label('avg_dental'),
        func.count(PetScanResult.id).label('scan_count')
    ).where(
        and_(
            PetScanResult.pet_id == pet_id,
            PetScanResult.timestamp >= thirty_days_ago,
            PetScanResult.id != latest_scan.id # exclude the current one from the historical average
        )
    )
    
    avg_result = await db.execute(avg_query)
    averages = avg_result.one()
    
    if averages.scan_count == 0:
        return {"status": "first_scan", "message": "First scan recorded. Need more data for trends."}
        
    def calc_delta(latest_val, avg_val):
        if avg_val is None or latest_val is None or avg_val == 0:
            return 0.0
        return round(((latest_val - avg_val) / avg_val) * 100, 2)

    trends = {
        "body_condition_delta_pct": calc_delta(latest_scan.body_condition_score, averages.avg_body),
        "coat_health_delta_pct": calc_delta(latest_scan.coat_health_score, averages.avg_coat),
        "eye_clarity_delta_pct": calc_delta(latest_scan.eye_clarity_score, averages.avg_eye),
        "dental_plaque_delta_pct": calc_delta(latest_scan.dental_plaque_score, averages.avg_dental),
    }
    
    return {
        "status": "success",
        "latest_scan_id": latest_scan.id,
        "historical_averages": {
            "avg_body": round(averages.avg_body, 2) if averages.avg_body else None,
            "avg_coat": round(averages.avg_coat, 2) if averages.avg_coat else None,
            "avg_eye": round(averages.avg_eye, 2) if averages.avg_eye else None,
            "avg_dental": round(averages.avg_dental, 2) if averages.avg_dental else None,
        },
        "trends": trends,
        "insights": generate_text_insights(trends)
    }

def generate_text_insights(trends: dict) -> list[str]:
    """Generates simple text string alerts based on threshold changes."""
    insights = []
    if trends["coat_health_delta_pct"] < -10.0:
        insights.append("Coat glossiness has dropped over 10% compared to the 30-day average. Consider checking diet or allergies.")
    if trends["coat_health_delta_pct"] > 10.0:
        insights.append("Coat is looking significantly healthier this month!")
    if trends["body_condition_delta_pct"] > 5.0:
        insights.append("Body condition score is trending upwards (potential weight gain). Keep an eye on portions.")
    if trends["dental_plaque_delta_pct"] < -15.0:
        insights.append("Dental score has decreased. Consider a brushing routine or dental chews.")
        
    if not insights:
        insights.append("All metrics are stable compared to the 30-day moving average.")
        
    return insights
