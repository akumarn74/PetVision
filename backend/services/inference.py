import os
import io
import json
import base64
import httpx
import logging

try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass

LLM_API_KEY = os.environ.get("OPENAI_API_KEY", "")

async def run_pet_inference(image_bytes: bytes, expected_pet_name: str, expected_breed: str) -> dict:
    """
    Production Engine: Replaces local YOLO models with OpenAI's `gpt-4o` Vision model
    capable of running zero-shot diagnostic inference directly on the user's photo.
    Returns exactly scoring metrics.
    """
    
    # Base64 encode the received buffer
    encoded_string = base64.b64encode(image_bytes).decode("utf-8")
    
    # 1. Immediate Rejection if they don't have OPENAI enabled yet
    if not LLM_API_KEY or LLM_API_KEY.strip() == "":
        raise ValueError("CRITICAL: OPENAI_API_KEY is completely missing from backend/.env. The Production Engine requires a real AI Key to execute Computer Vision.")
        
    system_prompt = (
        "You are 'PetVision AI', an elite veterinary AI diagnostic vision model. "
        f"You are evaluating a scan for a pet named '{expected_pet_name}' who is registered as a '{expected_breed}'. "
        "Analyze this precise image of an animal and predict 4 biometric health identifiers. YOU MUST ENFORCE HIGH VARIANCE! Look at the specific dog/cat, evaluate flaws, and give hyper-specific scores ranging from 35.0 to 98.0! "
        "CRITICAL IDENTITY CHECK: If the image is CLEARLY not a pet (e.g. a car, piece of furniture, human face), set 'is_fraud' to true and explain why in 'fraud_reason'. Note: Users might use shorthand for breeds (e.g. 'gold' for Golden Retriever), so be extremely lenient if the image is actually a dog or cat. Only trigger fraud if it's glaringly obvious the species is completely wrong or an inanimate object. Skip other metrics if fraud is detected. "
        "CRITICAL INSTRUCTION: If any specific biological metric (like teeth or eyes) is completely obscured by the camera angle, YOU MUST NOT HALLUCINATE A SCORE! You must set the score to exactly -1.0, and state 'Metric fully obscured. Cannot be evaluated from this angle.' in the analysis string! "
        "Outputs must be in strict JSON format. No markdown, no prefixes. JUST the JSON dictionary. "
        "Your JSON MUST contain exactly these 11 keys: "
        "'is_fraud' (boolean), 'fraud_reason' (string), "
        "'body_condition_score' (float), 'body_condition_analysis' (3 to 5 dense, clinically intensive sentences describing skeletal alignment, fat deposits, and muscular distribution explicitly mapped from the photo), "
        "'coat_health_score' (float), 'coat_health_analysis' (3 to 5 dense sentences evaluating pixel gloss matrices, shedding patterns, or hydration markers), "
        "'eye_clarity_score' (float), 'eye_clarity_analysis' (3 to 5 dense sentences analyzing sub-cornea lens opacity, sclera redness, and tear duct formations), "
        "'dental_plaque_score' (float), 'dental_plaque_analysis' (3 to 5 dense sentences scanning calculus boundary intersections or gumline inflammation), "
        "and 'ai_reflection' (A massive paragraph summarizing the animal's breed, age proxy, biological composition, and overriding psychological state based on their posture)."
    )
    
    payload = {
        "model": "gpt-4o",
        "messages": [
            {
                "role": "system",
                "content": system_prompt
            },
            {
                "role": "user",
                "content": [
                    {
                        "type": "text",
                        "text": "Analyze this pet strictly mapping the bounding boxes and outputting the JSON."
                    },
                    {
                        "type": "image_url",
                        "image_url": {
                            "url": f"data:image/jpeg;base64,{encoded_string}"
                        }
                    }
                ]
            }
        ],
        "response_format": {"type": "json_object"},
        "max_tokens": 400,
        "temperature": 0.7
    }

    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(
                "https://api.openai.com/v1/chat/completions",
                headers={
                    "Authorization": f"Bearer {LLM_API_KEY}",
                    "Content-Type": "application/json"
                },
                json=payload
            )
            response.raise_for_status()
            data = response.json()
            raw_text = data["choices"][0]["message"]["content"].strip()
            
            # Clean strict JSON markdown wrap if GPT messes up
            if raw_text.startswith("```json"):
                raw_text = raw_text[7:]
            if raw_text.startswith("```"):
                raw_text = raw_text[3:]
            if raw_text.endswith("```"):
                raw_text = raw_text[:-3]

            try:
                metrics_json = json.loads(raw_text.strip())
            except json.JSONDecodeError:
                raise ValueError(f"OpenAI Failed Json Decoding. Returned: {raw_text}")
            
            return {
                "detections": metrics_json,
                "metrics": {
                    "body_condition_score": float(metrics_json.get("body_condition_score", 85.0)),
                    "coat_health_score": float(metrics_json.get("coat_health_score", 88.0)),
                    "eye_clarity_score": float(metrics_json.get("eye_clarity_score", 92.0)),
                    "dental_plaque_score": float(metrics_json.get("dental_plaque_score", 75.0))
                }
            }
    except httpx.HTTPStatusError as e:
        status = e.response.status_code
        err_text = e.response.text
        logging.error(f"OpenAI GPT-4o Vision Failure: Code {status} - {err_text}")
        if status == 401:
            raise ValueError("OpenAI Authentication Error: Your API key is invalid or not activated.")
        elif status == 429:
            raise ValueError("OpenAI Billing Error: You have exceeded your quota or have no credits.")
        else:
            raise ValueError(f"OpenAI Pipeline Exception: {err_text}")
    except Exception as e:
        logging.error(f"OpenAI System Integrations Failure: {str(e)}")
        raise ValueError(f"CRITICAL SYSTEM FAILURE: {str(e)}")

async def run_onboarding_inference(image_bytes: bytes) -> dict:
    """Uses GPT-4o Vision to estimate the pet's breed, weight, and assigned vibe emoji based on a picture."""
    if not LLM_API_KEY or LLM_API_KEY.strip() == "":
        raise ValueError("OPENAI_API_KEY is missing.")

    encoded_string = base64.b64encode(image_bytes).decode("utf-8")
    system_prompt = (
        "You are PetVision AI. The user is registering a new pet profile. "
        "Analyze this image and identify the breed explicitly. Then estimate their average adult weight class in pounds based on that breed. "
        "Also pick exactly one emoji to represent the pet's species (e.g. 🐶 for dog, 🐱 for cat, 🐰 for rabbit). "
        "Output strict JSON with these keys exactly: 'breed' (string), 'weight_lbs' (float), 'vibe_emoji' (string)."
    )

    payload = {
        "model": "gpt-4o",
        "messages": [
            {"role": "system", "content": system_prompt},
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": "Identify this pet's breed and weight."},
                    {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{encoded_string}"}}
                ]
            }
        ],
        "response_format": {"type": "json_object"},
        "max_tokens": 100,
        "temperature": 0.3
    }

    try:
        async with httpx.AsyncClient(timeout=20.0) as client:
            response = await client.post(
                "https://api.openai.com/v1/chat/completions",
                headers={"Authorization": f"Bearer {LLM_API_KEY}", "Content-Type": "application/json"},
                json=payload
            )
            response.raise_for_status()
            data = response.json()
            return json.loads(data["choices"][0]["message"]["content"].strip())
    except Exception as e:
        logging.error(f"Onboarding Inference Failure: {str(e)}")
        raise ValueError(f"Failed to infer pet data: {str(e)}")
