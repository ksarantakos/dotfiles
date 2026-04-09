#!/bin/sh
set -eu

NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

# Existing npm prefix/globalconfig settings can break nvm activation on
# machines that were previously configured with a system-wide npm install.
# Keep this non-destructive: only clear process-local env vars and ignore the
# user's npmrc while bootstrapping Node under nvm.
unset NPM_CONFIG_PREFIX npm_config_prefix NPM_CONFIG_GLOBALCONFIG npm_config_globalconfig

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

NPM_CONFIG_USERCONFIG=/dev/null nvm install 24
NPM_CONFIG_USERCONFIG=/dev/null nvm use 24 >/dev/null
nvm alias default 24
