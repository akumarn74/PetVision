import boto3
from botocore.exceptions import ClientError
from fastapi import UploadFile
import os
import uuid

# MinIO Config
MINIO_ENDPOINT = os.environ.get("MINIO_ENDPOINT", "http://localhost:9000")
MINIO_ACCESS_KEY = os.environ.get("MINIO_ROOT_USER", "minioadmin")
MINIO_SECRET_KEY = os.environ.get("MINIO_ROOT_PASSWORD", "minioadmin")
BUCKET_NAME = "petvision-scans"

s3_client = boto3.client(
    's3',
    endpoint_url=MINIO_ENDPOINT,
    aws_access_key_id=MINIO_ACCESS_KEY,
    aws_secret_access_key=MINIO_SECRET_KEY,
)

def ensure_bucket_exists():
    try:
        s3_client.head_bucket(Bucket=BUCKET_NAME)
    except ClientError:
        s3_client.create_bucket(Bucket=BUCKET_NAME)
        print(f"Bucket '{BUCKET_NAME}' created.")

async def upload_file_to_s3(file: UploadFile, pet_id: uuid.UUID) -> str:
    """Uploads a fast API file to MinIO S3 and returns the public link."""
    ensure_bucket_exists()
    
    file_extension = file.filename.split(".")[-1]
    unique_filename = f"{pet_id}/{uuid.uuid4()}.{file_extension}"
    
    # Reset file pointer
    await file.seek(0)
    
    s3_client.upload_fileobj(
        file.file,
        BUCKET_NAME,
        unique_filename,
        ExtraArgs={"ContentType": file.content_type}
    )
    
    # Return formatted URL
    return f"{MINIO_ENDPOINT}/{BUCKET_NAME}/{unique_filename}"
