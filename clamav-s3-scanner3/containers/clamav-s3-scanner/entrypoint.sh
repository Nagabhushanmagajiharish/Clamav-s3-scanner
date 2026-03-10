#!/bin/sh
set -eu

freshclam || echo "freshclam failed; continuing with the current virus definitions"
exec python /app/scanner.py