#!/bin/bash
set -e

OS="$(uname -s)"
bootstrap_failed=0

_apt_get_linux() {
  sudo env DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get "$@"
}

_load_homebrew() {
  if command -v brew >/dev/null 2>&1; then
    return 0
  fi

  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

_mark_failed() {
  bootstrap_failed=1
  echo "Warning: $*" >&2
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

_configure_aws_sso() {
  local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/chezmoi"
  local config_file="$config_dir/chezmoi.toml"
  local profile_name="${AWS_PROFILE:-work-poweruser}"
  local sso_start_url_ref
  local sso_account_id_ref
  local sso_session
  local sso_role_name
  local region
  local sso_region

  if ! command -v aws >/dev/null 2>&1; then
    echo "AWS CLI is not installed yet; skipping AWS SSO profile check."
    return 0
  fi

  if aws configure list-profiles 2>/dev/null | grep -qx "$profile_name"; then
    echo "AWS profile already exists: $profile_name"
    return 0
  fi

  echo ""
  echo "AWS profile '$profile_name' was not found."
  echo "This repo keeps the SSO start URL and AWS account ID out of git."
  echo "If those values are in 1Password, the script can store local op:// refs in chezmoi config and render ~/.aws/config."
  echo ""

  if ! command -v op >/dev/null 2>&1; then
    _mark_failed "1Password CLI is unavailable; cannot configure AWS SSO profile '$profile_name'"
    return 0
  fi

  if ! op whoami >/dev/null 2>&1; then
    echo "1Password CLI is not authenticated."
    printf 'Sign in to 1Password now to configure AWS SSO? [y/N] '
    read -r aws_op_choice
    if [[ "$aws_op_choice" =~ ^[Yy]$ ]]; then
      op signin || {
        _mark_failed "1Password sign-in failed; AWS SSO profile '$profile_name' was not configured"
        return 0
      }
    else
      _mark_failed "AWS SSO profile '$profile_name' was not configured"
      return 0
    fi
  fi

  printf 'Configure AWS SSO profile %s now? [y/N] ' "$profile_name"
  read -r aws_config_choice
  if [[ ! "$aws_config_choice" =~ ^[Yy]$ ]]; then
    _mark_failed "AWS SSO profile '$profile_name' was not configured"
    return 0
  fi

  printf '1Password ref for SSO start URL: '
  read -r sso_start_url_ref
  printf '1Password ref for AWS account ID: '
  read -r sso_account_id_ref
  printf 'AWS profile name [%s]: ' "$profile_name"
  read -r profile_name_input
  profile_name="${profile_name_input:-$profile_name}"
  printf 'AWS SSO session name [work]: '
  read -r sso_session
  sso_session="${sso_session:-work}"
  printf 'AWS SSO role name [AWSPowerUserAccess]: '
  read -r sso_role_name
  sso_role_name="${sso_role_name:-AWSPowerUserAccess}"
  printf 'AWS default region [us-east-1]: '
  read -r region
  region="${region:-us-east-1}"
  printf 'AWS SSO region [us-east-1]: '
  read -r sso_region
  sso_region="${sso_region:-us-east-1}"

  if [[ -z "$sso_start_url_ref" || -z "$sso_account_id_ref" ]]; then
    _mark_failed "AWS SSO 1Password refs were not provided"
    return 0
  fi

  mkdir -p "$config_dir"
  if [[ -f "$config_file" && ! -f "$config_file.before-aws-sso" ]]; then
    cp "$config_file" "$config_file.before-aws-sso"
  fi

  if [[ -f "$config_file" ]] && grep -q '^\[data\.aws\]' "$config_file"; then
    echo "Updating existing [data.aws] in $config_file is not automated yet." >&2
    echo "Edit that block if the refs are wrong, then rerun this script." >&2
  else
    cat >>"$config_file" <<EOF

[data.aws]
  ssoStartURLRef = "$sso_start_url_ref"
  ssoAccountIDRef = "$sso_account_id_ref"
  ssoSession = "$sso_session"
  ssoRoleName = "$sso_role_name"
  profileName = "$profile_name"
  region = "$region"
  ssoRegion = "$sso_region"
EOF
  fi

  chezmoi apply ~/.aws/config || {
    _mark_failed "failed to render ~/.aws/config"
    return 0
  }

  if aws configure list-profiles 2>/dev/null | grep -qx "$profile_name"; then
    echo "AWS profile configured: $profile_name"
  else
    _mark_failed "AWS profile '$profile_name' still was not found after rendering ~/.aws/config"
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

  _load_homebrew

  # Install Homebrew if not present
  if ! command -v brew >/dev/null 2>&1; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    _load_homebrew
  fi

  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew installation completed, but brew is still not on PATH." >&2
    echo "Open a new shell or run: eval \"\$(/opt/homebrew/bin/brew shellenv)\"" >&2
    exit 1
  fi

  # Install 1Password app, CLI, and chezmoi
  # 1Password app must be installed before the CLI so the SSH agent socket is available
  brew install --cask 1password || _mark_failed "1Password app install failed"
  brew install --cask 1password-cli || _mark_failed "1Password CLI install failed"
  brew install chezmoi || _mark_failed "chezmoi install failed"

  if ! command -v chezmoi >/dev/null 2>&1; then
    echo "chezmoi is required to continue but is not available." >&2
    exit 1
  fi

  _prompt_1password

  # Pull/update and apply dotfiles (also runs run_before_* scripts, e.g. Oh My Zsh install)
  _init_or_update_chezmoi || exit 1

  # Install all Homebrew packages and casks
  brew bundle --file ~/.local/share/chezmoi/Brewfile || _mark_failed "brew bundle reported one or more failures"

  # Re-apply so run_after_* scripts can run with all tools available
  # (installs Powerlevel10k, configures iTerm2 prefs folder)
  chezmoi apply || _mark_failed "final chezmoi apply failed"
  _configure_aws_sso

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
  chezmoi apply || _mark_failed "final chezmoi apply failed"
  _configure_aws_sso

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
if [[ "$bootstrap_failed" -ne 0 ]]; then
  echo "Bootstrap completed with warnings/failures above. Open a new shell, fix the reported items, then rerun this script."
  exit 1
fi

echo "Done. Open a new shell to finish setup."
