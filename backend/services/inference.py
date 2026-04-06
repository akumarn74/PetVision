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

async def run_pet_inference(image_bytes: bytes) -> dict:
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
        "Analyze this image of an animal and predict 4 biometric health identifiers on a strictly 0.0 to 100.0 scale. "
        "Outputs must be in strict JSON format. No markdown, no prefixes, no wrapping code blocks. JUST the JSON dictionary. "
        "Keys must be exactly: 'body_condition_score', 'coat_health_score', 'eye_clarity_score', 'dental_plaque_score', 'ai_reflection'. "
        "DO NOT blindly default to 90 or 95. If an attribute is completely blocked from view, look at surrounding visual clues (breed, weight, aging) to generate a realistic estimation ranging anywhere from 40 to 95. "
        "The 'ai_reflection' key MUST contain exactly 2 sentences describing the physical composition, colors, breed, and immediate biological state of the exact animal you are looking at right now."
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
                "detections": [metrics_json.get("ai_reflection", "AI Diagnostic Complete.")],
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
