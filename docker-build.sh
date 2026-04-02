#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="stm32-builder"
VARIANT="${1:-stm32}"
FORCE_REBUILD="${2:-no}"

# Show help if requested
if [[ "$VARIANT" = "-h" || "$VARIANT" = "--help" ]]; then
    echo "Usage: $0 [variant] [force]"
    echo "  variant: stm32, stm32-jadard (default: stm32)"
    echo "  force:   'force' to rebuild Docker image"
    echo ""
    echo "Example: $0 stm32          # Build stm32 image, skip Docker build if exists"
    echo "         $0 stm32-jadard force # Build stm32-jadard, force Docker rebuild"
    exit 0
fi

# Validate variant
if [[ ! "$VARIANT" =~ ^(stm32|stm32-jadard)$ ]]; then
    echo "Error: variant must be one of: stm32, stm32-jadard"
    echo "       Use '$0 --help' for usage."
    exit 1
fi

# Build Docker image if it doesn't exist or forced
if [[ "$FORCE_REBUILD" = "force" ]] || ! docker image inspect "$IMAGE_NAME" &>/dev/null; then
    echo "Building Docker image $IMAGE_NAME..."
    docker build -t "$IMAGE_NAME" -f "$SCRIPT_DIR/Dockerfile" "$SCRIPT_DIR"
else
    echo "Docker image $IMAGE_NAME already exists, skipping build."
fi

echo "Running build for variant: $VARIANT"
echo "Note: The build will mount the current directory as /workspace"
echo "      Output will be in $SCRIPT_DIR/deploy/"

# Ensure deploy directory exists and is writable
mkdir -p "$SCRIPT_DIR/deploy"

# Run container with current directory mounted
docker run --rm \
    -v "$SCRIPT_DIR:/workspace" \
    -w /workspace \
    -e VARIANT="$VARIANT" \
    --privileged \
    "$IMAGE_NAME" \
    ./build-image.sh -v "$VARIANT"

echo "Build completed. Check $SCRIPT_DIR/deploy/ for output."