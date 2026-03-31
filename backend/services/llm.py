import os

# To be implemented with `grok`, `openai`, or `google.generativeai` package
LLM_API_KEY = os.environ.get("LLM_API_KEY", "mock-key")

async def generate_vet_report_summary(pet_name: str, trends_dict: dict, recent_insights: list[str]) -> str:
    """
    Simulates sending the latest TimescaleDB longitudinal metrics to an LLM 
    to generate a 'Vet-Ready' summary output.
    """
    
    # In a real scenario, we'd build a prompt:
    # prompt = f"Write a professional veterinary summary for {pet_name} based on the following 30-day moving averages: {trends_dict} and recent insights: {recent_insights}. Provide actionable dietary recommendations."
    # response = async_llm_client.generate(prompt)
    
    # MOCK implementation
    summary = f"Dear Vet,\n\n{pet_name} has been monitored daily via PetVision AI over the past month.\n\n"
    summary += "### 30-Day Health Trends:\n"
    
    if trends_dict and "status" in trends_dict and trends_dict["status"] == "success":
        trends = trends_dict.get("trends", {})
        summary += f"- Body Condition Score changed by {trends.get('body_condition_delta_pct', 0)}%\n"
        summary += f"- Coat Health Score changed by {trends.get('coat_health_delta_pct', 0)}%\n"
        summary += f"- Eye Clarity Score changed by {trends.get('eye_clarity_delta_pct', 0)}%\n"
        summary += f"- Dental Health Score changed by {trends.get('dental_plaque_delta_pct', 0)}%\n\n"
    else:
        summary += "Not enough longitudinal data to build a 30-day trend chart.\n\n"
        
    summary += "### App Insights:\n"
    for insight in recent_insights:
        summary += f"- {insight}\n"
        
    summary += "\nThis report was algorithmically analyzed from localized computer vision inferences and is not a clinical diagnosis. Please review with standard procedures."
    
    return summary
