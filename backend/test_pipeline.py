import httpx
import asyncio
import uuid
import os
from PIL import Image
import io

async def test_pipeline():
    # 1. Create a dummy image
    img = Image.new('RGB', (640, 640), color = 'brown')
    img_byte_arr = io.BytesIO()
    img.save(img_byte_arr, format='JPEG')
    file_bytes = img_byte_arr.getvalue()

    base_url = "http://localhost:8000/api"

    async with httpx.AsyncClient() as client:
        # 0. Create Mock Pet Profile
        print("\n--- Creating Pet Profile ---")
        pet_payload = {"name": "Max", "breed": "Golden Retriever", "age_months": 24, "baseline_weight": 70.5}
        response = await client.post(f"{base_url}/pets", json=pet_payload)
        print("Status Code:", response.status_code)
        pet_id = response.json().get("pet_id")
        print(f"Testing pipeline for Pet ID: {pet_id}")
        # 2. Upload Scan (Hits MinIO, YOLOv8, and TimescaleDB)
        print("\n--- Sending Scan ---")
        files = {'file': ('dummy.jpg', file_bytes, 'image/jpeg')}
        response = await client.post(f"{base_url}/scans/{pet_id}", files=files, timeout=30.0)
        print("Status Code:", response.status_code)
        try:
            print("Response:", response.json())
        except Exception:
            print("Text Response:", response.text)

        # 3. Test Trends
        print("\n--- Fetching Trends ---")
        response = await client.get(f"{base_url}/scans/{pet_id}/trends")
        print("Status Code:", response.status_code)
        try:
            print("Response:", response.json())
        except Exception:
            print("Text Response:", response.text)

        # 4. Test Vet Report
        print("\n--- Generating Vet Report ---")
        response = await client.get(f"{base_url}/scans/{pet_id}/vet_report")
        print("Status Code:", response.status_code)
        try:
            print("Response:", response.json())
        except Exception:
            print("Text Response:", response.text)

if __name__ == "__main__":
    asyncio.run(test_pipeline())
