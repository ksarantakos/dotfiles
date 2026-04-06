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

if [[ -n "$PLATFORM" ]]; then
  platform_flag=(--platform "$PLATFORM")
else
  platform_flag=()
fi

echo "==> docker-ubuntu test: $IMAGE${PLATFORM:+ on $PLATFORM}"

docker run --rm -i \
  "${platform_flag[@]}" \
  -v "$REPO_ROOT:/dotfiles:ro" \
  -e DEBIAN_FRONTEND=noninteractive \
  "$IMAGE" bash /dotfiles/test/docker-ubuntu-inner.sh

echo "==> PASSED: $IMAGE"
