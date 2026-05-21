#!/bin/bash
set -e

IMAGE_NAME="pipepipe-builder"
OUTPUT_DIR="./outputs"
GRADLE_CACHE_DIR="./gradle-cache"
BUILD_TYPE="${1:-debug}"

# Create gradle cache directory
mkdir -p "$GRADLE_CACHE_DIR"

# Build Docker image only if not exists or force rebuild
if [ "$1" != "quick" ] && [ "$1" != "skip-build" ]; then
    echo "=== Building Docker image ==="
    docker build -t "$IMAGE_NAME" .
fi

if [ "$1" = "skip-build" ]; then
    echo "=== Skipping Docker build, using existing image ==="
fi

# Run build with Gradle cache mounted
echo "=== Building $BUILD_TYPE APK ==="
docker run --rm \
    -v "$GRADLE_CACHE_DIR:/root/.gradle" \
    "$IMAGE_NAME" bash -c "cd /app/PipePipeClient && ./gradlew assemble$BUILD_TYPE --no-daemon -q"

# Copy APK to outputs
mkdir -p "$OUTPUT_DIR"
docker create --name pipepipe-temp "$IMAGE_NAME"
docker cp "pipepipe-temp:/app/PipePipeClient/app/build/outputs/apk/$BUILD_TYPE/." "$OUTPUT_DIR/"
docker rm pipepipe-temp

echo "=== APKs built successfully ==="
ls -lh "$OUTPUT_DIR"
