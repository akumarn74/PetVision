import os
import httpx
import logging

# Disable OS caching locally for live reloading during dev edits
import importlib
try:
    from dotenv import load_dotenv
    load_dotenv(override=True)
except ImportError:
    pass

LLM_API_KEY = os.environ.get("OPENAI_API_KEY", "")

async def generate_vet_report_summary(pet_name: str, trends_dict: dict, recent_insights: list[str]) -> str:
    """
    Simulates sending the latest TimescaleDB longitudinal metrics to an LLM 
    to generate a 'Vet-Ready' summary output.
    """
    
    # Check if we have longitudinal data
    has_trends = trends_dict and "status" in trends_dict and trends_dict["status"] == "success"
    trends = trends_dict.get("trends", {}) if has_trends else {}
    
    # 1. Fallback Mock Output if API Key is not set by the User yet
    if not LLM_API_KEY or LLM_API_KEY.strip() == "":
        mock = f"{pet_name} was scanned successfully. However, the AI System Prompt is currently disconnected.\n\nPlease open backend/.env and insert your real OPENAI_API_KEY to activate cutting-edge veterinary diagnostics via the Language Model."
        if has_trends:
            mock += f"\n\nRaw Delta: Body ({trends.get('body_condition_delta_pct', 0)}%), Coat ({trends.get('coat_health_delta_pct', 0)}%)"
        return mock
        
    # 2. Advanced Veterinary AI Prompt Engineering
    system_prompt = (
        "You are 'PetVision AI', an elite veterinary practitioner and diagnostic system. "
        "Analyze the provided biological metrics and visual insight data to provide an extremely professional, clinical, and empathetic medical summary for the patient. "
        "CRITICAL INSTRUCTIONS: "
        "- NEVER break character. You are the Vet."
        "- NEVER mention 'the app', 'the user', or 'the algorithm'. "
        "- Do not start with 'Dear Pet owner'. Begin the clinical assessment immediately. "
        "- Write in a seamless, unified paragraph. Be incredibly specific. Do not list bullet points. "
        "- End with exactly ONE actionable, scientific medical recommendation."
    )
    
    user_prompt = f"Patient: {pet_name}\n\n30-Day Metric Deltas (Percentage Changes):\n"
    if has_trends:
        user_prompt += f"Systemic Body Condition: {trends.get('body_condition_delta_pct', 0)}%\n"
        user_prompt += f"External Coat Health: {trends.get('coat_health_delta_pct', 0)}%\n"
        user_prompt += f"Ocular Clarity: {trends.get('eye_clarity_delta_pct', 0)}%\n"
        user_prompt += f"Periodontal/Dental Plaque: {trends.get('dental_plaque_delta_pct', 0)}%\n"
    else:
        user_prompt += "Insufficient tracking data for a 30-day moving average. This is the first recorded biometric scan.\n"
        
    user_prompt += f"\nComputer Vision Extracted Immediate Insights:\n"
    for inc in recent_insights:
        user_prompt += f"- {inc}\n"
        
    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            response = await client.post(
                "https://api.openai.com/v1/chat/completions",
                headers={
                    "Authorization": f"Bearer {LLM_API_KEY}",
                    "Content-Type": "application/json"
                },
                json={
                    "model": "gpt-4o-mini", # Super fast, extremely capable for clinical data parsing
                    "messages": [
                        {"role": "system", "content": system_prompt},
                        {"role": "user", "content": user_prompt}
                    ],
                    "temperature": 0.2, 
                    "max_tokens": 250
                }
            )
            response.raise_for_status()
            data = response.json()
            return data["choices"][0]["message"]["content"].strip()
            
    except Exception as e:
        logging.error(f"OpenAI Integrations Failure: {str(e)}")
        # Graceful degradation to fallback text if OpenAI is down or the key is invalid
        return f"Veterinary AI engine temporarily unavailable (Error: API Key validation failed or Network timeout). Please verify your OPENAI_API_KEY in the `.env` file."

async def generate_temporal_delta_context(pet_name: str, build_profile_str: str, trends: dict) -> dict:
    """
    Passes mathematical delta percentages to GPT-4o-mini. Returns customized, highly dense
    JSON strings replacing rigid dart fallbacks with actual LLM Trajectory analysis.
    """
    if not LLM_API_KEY or LLM_API_KEY.strip() == "":
        return {} # Fails silently, Frontend natively falls back

    system_prompt = (
        "You are 'PetVision AI', an elite veterinary tracking model. "
        "Analyze these 30-day percentage deltas and generate custom trajectory tracking analysis. "
        "Return STRICT JSON with these exactly 8 keys: "
        "'body_context', 'body_trajectory', 'coat_context', 'coat_trajectory', "
        "'eye_context', 'eye_trajectory', 'dental_context', 'dental_trajectory'. "
        "Contexts should be 1-2 dense sentences explaining the biological tracking metric itself. "
        "Trajectories should be 2-3 dense sentences explaining what the specific math (+2.4%, -1.1%) means clinically for this exact pet!"
    )

    user_prompt = f"Patient: {pet_name} - {build_profile_str}\n\n"
    user_prompt += f"Systemic Body Condition: {trends.get('body_condition_delta_pct', 0)}% moving average change\n"
    user_prompt += f"External Coat Health: {trends.get('coat_health_delta_pct', 0)}% moving average change\n"
    user_prompt += f"Ocular Clarity: {trends.get('eye_clarity_delta_pct', 0)}% moving average change\n"
    user_prompt += f"Dental Plaque: {trends.get('dental_plaque_delta_pct', 0)}% moving average change\n"

    try:
        async with httpx.AsyncClient(timeout=20.0) as client:
            response = await client.post(
                "https://api.openai.com/v1/chat/completions",
                headers={"Authorization": f"Bearer {LLM_API_KEY}", "Content-Type": "application/json"},
                json={
                    "model": "gpt-4o-mini",
                    "response_format": {"type": "json_object"},
                    "messages": [
                        {"role": "system", "content": system_prompt},
                        {"role": "user", "content": user_prompt}
                    ],
                    "temperature": 0.4,
                    "max_tokens": 500
                }
            )
            response.raise_for_status()
            import json
            data = response.json()
            return json.loads(data["choices"][0]["message"]["content"])
    except Exception as e:
        logging.error(f"OpenAI Temporal AI Failure: {str(e)}")
        return {}
