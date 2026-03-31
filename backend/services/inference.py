import torch
from ultralytics import YOLO
import random
import os

# Load the pretrained model (weights will automatically download)
MODEL_PATH = "yolov8n.pt"
try:
    model = YOLO(MODEL_PATH)
except Exception as e:
    print(f"Failed to load YOLO model: {e}")
    model = None

def run_pet_inference(image_bytes: bytes):
    """
    Run YOLOv8 on an image. Return bounding box info and mock health classification scores.
    """
    if model is None:
        raise ValueError("YOLO Model is not loaded properly.")
    
    # Save bytes to a temp file for YOLO processing (since ultralytics prefers local files/arrays)
    temp_file = "temp_inference.jpg"
    with open(temp_file, "wb") as f:
        f.write(image_bytes)

    # Inference
    results = model(temp_file)
    os.remove(temp_file)
    
    # Parse bounding boxes
    boxes_json = results[0].boxes.data.tolist()

    # Stub Mock Data for Longitudinal Metrics
    # (These will eventually be replaced by the fine-tuned custom vision models)
    mock_body_condition = round(random.uniform(40.0, 95.0), 2) # e.g. 100 is overweight, 0 is underweight
    mock_coat_health = round(random.uniform(70.0, 100.0), 2)
    mock_eye_clarity = round(random.uniform(85.0, 100.0), 2)
    mock_dental = round(random.uniform(50.0, 95.0), 2)

    return {
        "detections": boxes_json,
        "metrics": {
            "body_condition_score": mock_body_condition,
            "coat_health_score": mock_coat_health,
            "eye_clarity_score": mock_eye_clarity,
            "dental_plaque_score": mock_dental
        }
    }
