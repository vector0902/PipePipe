#!/bin/bash
set -e

IMAGE_NAME="pipepipe-builder"
OUTPUT_DIR="./outputs"
GRADLE_CACHE_DIR="./gradle-cache"
BUILD_DIR="./build"
BUILD_TYPE="debug"

# Parse arguments
SKIP_DOCKER_BUILD=0
for arg in "$@"; do
    case $arg in
        skip-build)
            SKIP_DOCKER_BUILD=1
            ;;
        release)
            BUILD_TYPE="release"
            ;;
        *)
            ;;
    esac
done

# Create directories
mkdir -p "$GRADLE_CACHE_DIR"
mkdir -p "$OUTPUT_DIR"
mkdir -p "$BUILD_DIR"

# Step 1: Build Docker image (no gradle build inside, just JDK + SDK)
if [ "$SKIP_DOCKER_BUILD" -eq 0 ]; then
    echo "=== Building Docker image (JDK + SDK only) ==="
    docker build -t "$IMAGE_NAME" --target builder .
else
    echo "=== Skipping Docker build ==="
fi

# Step 2: Run gradle build with mounted code + build dir + gradle cache
# This is where the actual compilation happens, and results are persisted to ./build
echo "=== Building $BUILD_TYPE APK (mounted, incremental) ==="
docker run --rm \
    -v "$GRADLE_CACHE_DIR:/root/.gradle" \
    -v "$(pwd)/PipePipeClient:/app/PipePipeClient" \
    -v "$(pwd)/PipePipeExtractor:/app/PipePipeExtractor" \
    -v "$(pwd)/build:/app/PipePipeClient/app/build" \
    "$IMAGE_NAME" bash -c "cd /app/PipePipeClient && ./gradlew assemble$BUILD_TYPE --no-daemon"

# Copy APK to outputs
mkdir -p "$OUTPUT_DIR"
cp -f build/app/build/outputs/apk/$BUILD_TYPE/*.apk "$OUTPUT_DIR/" 2>/dev/null || true
echo "=== Build complete ==="
ls -la "$OUTPUT_DIR"

echo "=== APKs built successfully ==="
ls -lh "$OUTPUT_DIR"
