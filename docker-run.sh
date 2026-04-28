#!/usr/bin/env bash
set -euo pipefail

IMAGE="${IMAGE:-api-omnivoice:latest}"
NAME="${NAME:-api-omnivoice}"
PORT="${PORT:-8091}"

if [[ ! -f .env ]]; then
  echo "ERROR: .env not found. Run:"
  echo "  cp .env.example .env"
  exit 1
fi

docker build -t "$IMAGE" .

docker rm -f "$NAME" >/dev/null 2>&1 || true

docker run --rm -it \
  --name "$NAME" \
  --gpus all \
  --ipc=host \
  --ulimit memlock=-1 \
  --ulimit stack=67108864 \
  -p "${PORT}:8091" \
  --env-file .env \
  -v "$PWD/.cache:/app/.cache" \
  "$IMAGE"
