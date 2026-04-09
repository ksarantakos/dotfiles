#!/bin/sh
set -eu

NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

# Load nvm: try Homebrew (macOS), then ~/.nvm (Linux already-installed), then install via curl
if command -v brew >/dev/null 2>&1 && [ -s "$(brew --prefix)/opt/nvm/nvm.sh" ]; then
  . "$(brew --prefix)/opt/nvm/nvm.sh"
elif [ -s "$NVM_DIR/nvm.sh" ]; then
  . "$NVM_DIR/nvm.sh"
elif command -v curl >/dev/null 2>&1; then
  echo "Installing nvm via curl..."
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.2/install.sh | bash
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
else
  echo "nvm not found and curl unavailable, skipping Node install" >&2
  exit 0
fi

nvm install 24
nvm alias default 24
