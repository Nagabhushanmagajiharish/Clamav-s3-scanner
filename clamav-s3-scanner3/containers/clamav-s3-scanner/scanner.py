import json
import logging
import os
import subprocess
import tempfile
import time
from pathlib import Path
from urllib.parse import unquote_plus

import boto3

logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO"),
    format="%(asctime)s %(levelname)s %(message)s",
)
LOGGER = logging.getLogger(__name__)

SOURCE_BUCKET = os.environ["SOURCE_BUCKET"]
CLEAN_BUCKET = os.environ["CLEAN_BUCKET"]
INFECTED_BUCKET = os.environ["INFECTED_BUCKET"]
QUEUE_URL = os.environ["QUEUE_URL"]
OBJECT_PREFIX = os.environ.get("OBJECT_PREFIX", "uploads/")
DELETE_SOURCE_OBJECT = os.environ.get("DELETE_SOURCE_OBJECT", "false").lower() == "true"
POLL_WAIT_SECONDS = int(os.environ.get("POLL_WAIT_SECONDS", "20"))
POLL_MAX_MESSAGES = min(int(os.environ.get("POLL_MAX_MESSAGES", "1")), 10)
FRESHCLAM_INTERVAL_SECONDS = int(os.environ.get("FRESHCLAM_INTERVAL_SECONDS", "21600"))
WORK_DIR = Path(os.environ.get("WORK_DIR", "/tmp/clamav"))
WORK_DIR.mkdir(parents=True, exist_ok=True)

session = boto3.session.Session(region_name=os.environ.get("AWS_REGION"))
s3 = session.client("s3")
sqs = session.client("sqs")
last_definition_refresh = 0.0


def refresh_definitions(force=False):
    global last_definition_refresh

    now = time.time()
    if not force and now - last_definition_refresh < FRESHCLAM_INTERVAL_SECONDS:
        return

    result = subprocess.run(
        ["freshclam", "--stdout"],
        capture_output=True,
        text=True,
        check=False,
    )
    last_definition_refresh = now

    if result.stdout.strip():
        LOGGER.info(result.stdout.strip())
    if result.stderr.strip():
        LOGGER.warning(result.stderr.strip())

    if result.returncode != 0:
        LOGGER.warning(
            "freshclam returned exit code %s; continuing with the current database",
            result.returncode,
        )


def scan_file(path):
    refresh_definitions()
    result = subprocess.run(
        ["clamscan", "--stdout", "--no-summary", str(path)],
        capture_output=True,
        text=True,
        check=False,
    )
    output = "\n".join(part.strip() for part in (result.stdout, result.stderr) if part.strip())

    if result.returncode == 0:
        return "clean", output or "clean"
    if result.returncode == 1:
        return "infected", output or "infected"

    raise RuntimeError(f"clamscan failed with exit code {result.returncode}: {output}")


def tag_object(bucket, key, status):
    s3.put_object_tagging(
        Bucket=bucket,
        Key=key,
        Tagging={
            "TagSet": [
                {"Key": "scan-status", "Value": status},
                {"Key": "scanner", "Value": "clamav"},
            ]
        },
    )


def copy_result_object(source_key, destination_bucket, status):
    s3.copy_object(
        Bucket=destination_bucket,
        Key=source_key,
        CopySource={"Bucket": SOURCE_BUCKET, "Key": source_key},
        TaggingDirective="REPLACE",
        Tagging=f"scan-status={status}&scanner=clamav",
    )


def maybe_delete_source_object(key):
    if DELETE_SOURCE_OBJECT:
        s3.delete_object(Bucket=SOURCE_BUCKET, Key=key)


def process_record(record):
    bucket_name = record["s3"]["bucket"]["name"]
    object_key = unquote_plus(record["s3"]["object"]["key"])

    if bucket_name != SOURCE_BUCKET:
        LOGGER.info("Skipping event for bucket %s", bucket_name)
        return

    if OBJECT_PREFIX and not object_key.startswith(OBJECT_PREFIX):
        LOGGER.info("Skipping key outside prefix %s: %s", OBJECT_PREFIX, object_key)
        return

    with tempfile.TemporaryDirectory(dir=WORK_DIR) as temp_dir:
        local_path = Path(temp_dir) / Path(object_key).name
        LOGGER.info("Downloading s3://%s/%s", SOURCE_BUCKET, object_key)
        s3.download_file(SOURCE_BUCKET, object_key, str(local_path))

        status, scan_output = scan_file(local_path)
        destination_bucket = CLEAN_BUCKET if status == "clean" else INFECTED_BUCKET

        LOGGER.info("Scan result for %s: %s", object_key, status)
        if scan_output:
            LOGGER.info(scan_output)

        copy_result_object(object_key, destination_bucket, status)
        tag_object(SOURCE_BUCKET, object_key, status)
        maybe_delete_source_object(object_key)


def process_message(message):
    body = json.loads(message["Body"])
    records = body.get("Records", [])
    for record in records:
        process_record(record)

    sqs.delete_message(QueueUrl=QUEUE_URL, ReceiptHandle=message["ReceiptHandle"])


def poll_once():
    response = sqs.receive_message(
        QueueUrl=QUEUE_URL,
        MaxNumberOfMessages=POLL_MAX_MESSAGES,
        WaitTimeSeconds=POLL_WAIT_SECONDS,
        MessageAttributeNames=["All"],
    )
    return response.get("Messages", [])


def main():
    refresh_definitions(force=True)
    LOGGER.info("Listening for scan jobs on %s", QUEUE_URL)

    while True:
        messages = poll_once()
        if not messages:
            continue

        for message in messages:
            try:
                process_message(message)
            except Exception:
                LOGGER.exception("Failed to process message %s", message.get("MessageId"))


if __name__ == "__main__":
    main()