#!/usr/bin/env bash
# Run the Linux bootstrap inside a fresh Ubuntu container.
#
# Usage:
#   bash test/docker-ubuntu.sh                            # ubuntu:24.04, host arch
#   bash test/docker-ubuntu.sh ubuntu:22.04               # Ubuntu 22.04
#   bash test/docker-ubuntu.sh ubuntu:24.04 linux/arm64   # RPi simulation (Apple Silicon)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE="${1:-ubuntu:24.04}"
PLATFORM="${2:-}"

if ! docker info >/dev/null 2>&1; then
  echo "Error: Docker is not running. Start Docker Desktop and try again." >&2
  exit 1
fi

echo "==> docker-ubuntu test: $IMAGE${PLATFORM:+ on $PLATFORM}"

# "${var[@]+"${var[@]}"}" is the bash 3.2-safe way to expand an array that may be empty under set -u
if [[ -n "$PLATFORM" ]]; then
  docker run --rm -i \
    --platform "$PLATFORM" \
    -v "$REPO_ROOT:/dotfiles:ro" \
    -e DEBIAN_FRONTEND=noninteractive \
    "$IMAGE" bash /dotfiles/test/docker-ubuntu-inner.sh
else
  docker run --rm -i \
    -v "$REPO_ROOT:/dotfiles:ro" \
    -e DEBIAN_FRONTEND=noninteractive \
    "$IMAGE" bash /dotfiles/test/docker-ubuntu-inner.sh
fi

echo "==> PASSED: $IMAGE"
