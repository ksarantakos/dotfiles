#!/bin/sh
set -eu

NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
NPMRC_BACKUP_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/npm-backups"
NPMRC_PATH="$HOME/.npmrc"

# Existing npm prefix/globalconfig settings can break nvm activation on
# machines that were previously configured with a system-wide npm install.
# Keep this non-destructive: clear process-local env vars and, if needed,
# back up only the conflicting keys from the user's npmrc before bootstrapping
# Node under nvm.
unset NPM_CONFIG_PREFIX npm_config_prefix NPM_CONFIG_GLOBALCONFIG npm_config_globalconfig

sanitize_npmrc_for_nvm() {
  [ -f "$NPMRC_PATH" ] || return 0

  if ! grep -Eq '^(prefix|globalconfig)=' "$NPMRC_PATH"; then
    return 0
  fi

  mkdir -p "$NPMRC_BACKUP_DIR"
  backup_path="$NPMRC_BACKUP_DIR/npmrc.pre-nvm"

  if [ ! -f "$backup_path" ]; then
    cp "$NPMRC_PATH" "$backup_path"
  fi

  tmp_path="$(mktemp)"
  grep -Ev '^(prefix|globalconfig)=' "$NPMRC_PATH" >"$tmp_path" || true
  mv "$tmp_path" "$NPMRC_PATH"
}

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

sanitize_npmrc_for_nvm
nvm install 24
nvm use 24 >/dev/null
nvm alias default 24
