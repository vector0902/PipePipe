#!/bin/bash
set -e

IMAGE_NAME="pipepipe-builder"
OUTPUT_DIR="./outputs"

if [ "$1" != "quick" ]; then
    docker build -t "$IMAGE_NAME" .
fi

docker run --rm "$IMAGE_NAME" bash -c 'cd /app/PipePipeClient && ./gradlew assembleDebug --no-daemon -q'

mkdir -p "$OUTPUT_DIR"
docker create --name pipepipe-temp "$IMAGE_NAME"
docker cp pipepipe-temp:/app/PipePipeClient/app/build/outputs/apk/debug/. "$OUTPUT_DIR/"
docker rm pipepipe-temp

echo "=== APKs built successfully ==="
ls -la "$OUTPUT_DIR"