#!/bin/bash
set -e

# Install Homebrew if not present
if ! command -v brew >/dev/null 2>&1; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Add Homebrew to PATH for the rest of this script (Apple Silicon / Intel)
  if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -f /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
fi

# Install chezmoi and 1Password CLI
brew install chezmoi 1password-cli

# Sign in to 1Password
op signin

# Pull and apply dotfiles (also runs run_once_before_* scripts, e.g. Oh My Zsh install)
chezmoi init --apply https://github.com/ksarantakos/dotfiles

# Install all Homebrew packages and casks
brew bundle --file ~/.local/share/chezmoi/Brewfile

# Re-apply so run_once_after_* scripts can run with all tools available
# (installs Powerlevel10k, configures iTerm2 prefs folder)
chezmoi apply

echo ""
echo "Done. Open a new shell to finish setup."
