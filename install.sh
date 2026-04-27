#!/bin/bash
set -e

OS="$(uname -s)"

_apt_get_linux() {
  sudo env DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get "$@"
}

_prompt_1password() {
  echo ""
  echo "1Password sign-in is only required if this machine needs access to the private NBC News Nexus NPM registry."
  echo "Skip it if you only need public npm packages."
  echo ""

  if ! command -v op >/dev/null 2>&1; then
    echo "1Password CLI (op) not found — skipping. To use private NPM packages later, install op and run: op signin && chezmoi apply"
    return 0
  fi

  printf 'Sign in to 1Password now? [y/N] '
  read -r sign_in_choice

  if [[ "$sign_in_choice" =~ ^[Yy]$ ]]; then
    op signin
  else
    echo "Skipping 1Password sign-in. ~/.npmrc will not be rendered; private Nexus packages will be unavailable."
  fi
}

_install_gh_linux() {
  sudo mkdir -p -m 755 /etc/apt/keyrings
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
  sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
  local arch
  arch="$(dpkg --print-architecture 2>/dev/null || uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')"
  echo "deb [arch=${arch} signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
  _apt_get_linux update -qq
  _apt_get_linux install -y gh
}

_init_or_update_chezmoi() {
  local repo_url="https://github.com/ksarantakos/dotfiles"
  local dotfiles_ref="${DOTFILES_REF:-master}"
  local source_dir

  source_dir="$(chezmoi source-path 2>/dev/null || printf '%s/.local/share/chezmoi' "$HOME")"

  if [[ -d "$source_dir/.git" ]]; then
    echo "Updating existing chezmoi source at $source_dir to $dotfiles_ref..."
    git -C "$source_dir" fetch origin "$dotfiles_ref"
    git -C "$source_dir" checkout -B "$dotfiles_ref" FETCH_HEAD
    chezmoi apply
  else
    chezmoi init --branch "$dotfiles_ref" --apply "$repo_url"
  fi
}

if [[ "$OS" == "Darwin" ]]; then
  # ── macOS ──────────────────────────────────────────────────────────────────

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

  # Install 1Password app, CLI, and chezmoi
  # 1Password app must be installed before the CLI so the SSH agent socket is available
  brew install --cask 1password
  brew install --cask 1password-cli
  brew install chezmoi

  _prompt_1password

  # Pull/update and apply dotfiles (also runs run_before_* scripts, e.g. Oh My Zsh install)
  _init_or_update_chezmoi

  # Install all Homebrew packages and casks
  brew bundle --file ~/.local/share/chezmoi/Brewfile

  # Re-apply so run_after_* scripts can run with all tools available
  # (installs Powerlevel10k, configures iTerm2 prefs folder)
  chezmoi apply

elif [[ "$OS" == "Linux" ]]; then
  # ── Linux (Ubuntu / Raspberry Pi OS) ──────────────────────────────────────

  echo "Installing base dependencies via apt..."
  _apt_get_linux update -qq
  _apt_get_linux install -y curl git zsh build-essential

  # Install chezmoi if not present
  if ! command -v chezmoi >/dev/null 2>&1; then
    echo "Installing chezmoi..."
    sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
    export PATH="$HOME/.local/bin:$PATH"
  fi

  _prompt_1password

  # Pull/update and apply dotfiles (also runs run_before_* scripts, e.g. Oh My Zsh install)
  _init_or_update_chezmoi

  # Install packages listed in the repo (excludes gh and eza — handled below)
  apt_packages="$HOME/.local/share/chezmoi/apt-packages.txt"
  if [[ -f "$apt_packages" ]]; then
    echo "Installing apt packages..."
    # shellcheck disable=SC2046
    _apt_get_linux install -y $(grep -v '^\s*#' "$apt_packages" | grep -v '^\s*$' | tr '\n' ' ')
  fi

  # Install GitHub CLI via its official apt repository
  if ! command -v gh >/dev/null 2>&1; then
    echo "Installing GitHub CLI..."
    _install_gh_linux || echo "Warning: could not install gh. See https://cli.github.com for manual install instructions."
  fi

  # Install eza if available on this distro (Ubuntu 24.04+ / Debian 12+; silently skipped otherwise)
  _apt_get_linux install -y eza 2>/dev/null || true

  # Re-apply so run_after_* scripts can run with all tools available
  chezmoi apply

  # Suggest setting zsh as default shell if it isn't already
  if command -v zsh >/dev/null 2>&1 && [[ "$SHELL" != "$(command -v zsh)" ]]; then
    echo ""
    echo "zsh is installed. To set it as your default shell, run:"
    echo "  chsh -s \$(which zsh)"
  fi

else
  echo "Unsupported OS: $OS" >&2
  exit 1
fi

echo ""
echo "Done. Open a new shell to finish setup."
