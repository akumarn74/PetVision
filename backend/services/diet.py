import json
import httpx
from typing import Dict
from backend.services.inference import LLM_API_KEY
import logging

async def parse_unstructured_meal_to_json(raw_query: str, pet_name: str, breed: str, weight: float) -> Dict:
    """
    Acts as the Cal AI engine. Takes '1 cup of kibbles and a slice of ham', queries OpenAI,
    and calculates macros based on the breed/weight metadata for sizing estimates.
    """
    if not LLM_API_KEY:
        raise ValueError("OPENAI_API_KEY Missing.")

    system_prompt = (
        "You are an elite veterinary nutritional AI. Your job is to act like a calorie tracker apps 'quick enter' feature. "
        "The user will type what their pet ate. "
        f"The pet is a '{breed}' named '{pet_name}' weighing {weight}lbs. Use this to estimate portion sizes if they are ambiguous. "
        "Return STRICT JSON with EXACTLY these keys: "
        "'food_name' (string, a clean summary of the items), "
        "'calories' (float, total estimated kcal), "
        "'proteins_g' (float), "
        "'fats_g' (float)."
    )

    payload = {
        "model": "gpt-4o-mini",
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": f"The pet ate: {raw_query}"}
        ],
        "response_format": {"type": "json_object"},
        "temperature": 0.1
    }

    async with httpx.AsyncClient(timeout=15.0) as client:
        response = await client.post(
            "https://api.openai.com/v1/chat/completions",
            headers={
                "Authorization": f"Bearer {LLM_API_KEY}",
                "Content-Type": "application/json"
            },
            json=payload
        )
        response.raise_for_status()
        raw_text = response.json()["choices"][0]["message"]["content"].strip()
        
        try:
            metrics_json = json.loads(raw_text)
            return {
                "food_name": metrics_json.get("food_name", raw_query),
                "calories": float(metrics_json.get("calories", 0.0)),
                "proteins_g": float(metrics_json.get("proteins_g", 0.0)),
                "fats_g": float(metrics_json.get("fats_g", 0.0)),
            }
        except json.JSONDecodeError:
            logging.error(f"Failed to parse Nutrition AI: {raw_text}")
            raise ValueError(f"AI returned invalid nutrition parameters.")

async def generate_dietary_recommendation(pet_name: str, breed: str, weight: float, body_condition_score: float, todays_calories: float) -> str:
    """
    Takes the aggregated database sums for today's logs, and compares it to their vision score!
    """
    if not LLM_API_KEY:
        return "Upgrade to Premium to unlock AI Dietary Recommendations."

    system_prompt = (
        f"You are PetVision Nutritional AI. The pet is '{pet_name}', a {breed} weighing {weight}lbs. "
        f"Their latest Vision AI Body Condition Score is {body_condition_score}/100. "
        f"Today, they have consumed a total of {todays_calories} kcal. "
        "Write exactly ONE compact, brilliant paragraph advising the owner on calorie pacing for the rest of the day, "
        "factoring in their Body Condition. Limit to 3 sentences."
    )

    payload = {
        "model": "gpt-4o-mini",
        "messages": [{"role": "user", "content": system_prompt}],
        "max_tokens": 150
    }

    async with httpx.AsyncClient(timeout=10.0) as client:
        response = await client.post(
            "https://api.openai.com/v1/chat/completions",
            headers={"Authorization": f"Bearer {LLM_API_KEY}", "Content-Type": "application/json"},
            json=payload
        )
        response.raise_for_status()
        response.raise_for_status()
        return response.json()["choices"][0]["message"]["content"].strip()


async def calculate_target_calories(pet_name: str, breed: str, weight: float, age_months: int, activity_level: str, diet_goal: str) -> float:
    """
    Generates a metabolic daily caloric target based on pet metrics and their selected goal.
    """
    if not LLM_API_KEY:
        return 1000.0 # fallback
        
    system_prompt = (
        "You are an elite veterinary metabolic AI. Return STRICT JSON. "
        "Calculate the daily caloric requirement (kcal) for this pet. "
        "Consider their age, breed baseline, weight, activity_level (couch_potato, moderate, active), and diet_goal (lose_weight, maintain, gain_weight). "
        "Return exactly one key: {'target_calories': float}"
    )
    
    payload = {
        "model": "gpt-4o-mini",
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": f"Pet {pet_name}, Breed: {breed}, Weight: {weight}lbs, Age: {age_months} months, Activity: {activity_level}, Goal: {diet_goal}."}
        ],
        "response_format": {"type": "json_object"},
        "temperature": 0.1
    }
    
    async with httpx.AsyncClient(timeout=10.0) as client:
        response = await client.post(
            "https://api.openai.com/v1/chat/completions",
            headers={"Authorization": f"Bearer {LLM_API_KEY}", "Content-Type": "application/json"},
            json=payload
        )
        response.raise_for_status()
        try:
            return float(json.loads(response.json()["choices"][0]["message"]["content"])["target_calories"])
        except Exception:
            return 1000.0


async def parse_food_image_to_json(image_base64: str, pet_name: str, breed: str, weight: float, goal: str) -> Dict:
    """
    Acts as the Vision Cal AI tracker. Evaluates an image of food and extracts Macros.
    """
    if not LLM_API_KEY:
        raise ValueError("OPENAI_API_KEY Missing.")

    system_prompt = (
        "You are an elite veterinary nutritional AI with computer vision. "
        "You are parsing an image of pet food. "
        f"The pet eating this is a '{breed}' named '{pet_name}' weighing {weight}lbs with a goal to '{goal}'. "
        "Examine the volume in the bowl, identify the brand/type of food if possible, and estimate the macros. "
        "Return STRICT JSON with EXACTLY these keys: "
        "'food_name' (string, '1.5 cups of Purina Dog Chow'), "
        "'calories' (float), "
        "'proteins_g' (float), "
        "'fats_g' (float)."
    )

    payload = {
        "model": "gpt-4o",
        "messages": [
            {"role": "system", "content": system_prompt},
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": "Analyze this food."},
                    {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{image_base64}"}}
                ]
            }
        ],
        "max_tokens": 300,
        "temperature": 0.1
    }

    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.post(
            "https://api.openai.com/v1/chat/completions",
            headers={"Authorization": f"Bearer {LLM_API_KEY}", "Content-Type": "application/json"},
            json=payload
        )
        response.raise_for_status()
        
        content = response.json()["choices"][0]["message"]["content"].strip()
        
        # Clean JSON if GPT returned markdown ticks
        if content.startswith("```json"):
            content = content[7:-3]
            
        try:
            metrics = json.loads(content)
            return {
                "food_name": metrics.get("food_name", "AI Vision Scanned Meal"),
                "calories": float(metrics.get("calories", 300.0)),
                "proteins_g": float(metrics.get("proteins_g", 0.0)),
                "fats_g": float(metrics.get("fats_g", 0.0)),
            }
        except json.JSONDecodeError:
            raise ValueError("Failed to run Image inference.")
