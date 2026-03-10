import boto3
import json
import os
from urllib.parse import unquote

BUCKET = os.environ["BUCKET_NAME"]
REGION = os.environ["REGION"]

s3 = boto3.client(
    "s3",
    region_name=REGION,
    endpoint_url=f"https://s3.{REGION}.amazonaws.com"
)

def lambda_handler(event, context):
    params = event.get("queryStringParameters") or {}
    filename = params.get("filename")

    if not filename:
        return {
            "statusCode": 400,
            "body": json.dumps({"message": "filename is required"})
        }

    filename = os.path.basename(unquote(filename))
    key = f"uploads/{filename}"

    url = s3.generate_presigned_url(
        ClientMethod="put_object",
        Params={
            "Bucket": BUCKET,
            "Key": key,
            "ContentType": "application/octet-stream"
        },
        ExpiresIn=300
    )

    return {
        "statusCode": 200,
        "body": json.dumps({
            "upload_url": url,
            "key": key
        })
    }
