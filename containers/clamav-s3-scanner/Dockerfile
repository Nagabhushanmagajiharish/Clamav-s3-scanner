FROM python:3.11-slim-bookworm

RUN apt-get update \
    && apt-get install -y --no-install-recommends clamav clamav-freshclam ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY scanner.py entrypoint.sh ./
RUN chmod +x /app/entrypoint.sh \
    && mkdir -p /var/lib/clamav /tmp/clamav

ENV PYTHONUNBUFFERED=1

ENTRYPOINT ["/app/entrypoint.sh"]