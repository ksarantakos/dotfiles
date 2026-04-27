#!/bin/sh
set -eu

failures=0
warnings=0
os_name=$(uname -s)

ok() {
  printf '[OK]   %s\n' "$1"
}

warn() {
  warnings=$((warnings + 1))
  printf '[WARN] %s\n' "$1"
}

fail() {
  failures=$((failures + 1))
  printf '[FAIL] %s\n' "$1"
}

have_command() {
  command -v "$1" >/dev/null 2>&1
}

require_command() {
  if have_command "$1"; then
    ok "$1: $(command -v "$1")"
  else
    fail "$1 not found"
  fi
}

check_command() {
  if have_command "$1"; then
    ok "$1: $(command -v "$1")"
  else
    warn "$1 not found"
  fi
}

run_with_timeout() {
  timeout_seconds=$1
  shift

  if have_command gtimeout; then
    gtimeout "$timeout_seconds" "$@"
  elif have_command timeout; then
    timeout "$timeout_seconds" "$@"
  else
    perl -e 'alarm shift; exec @ARGV' "$timeout_seconds" "$@"
  fi
}

meslo_font_installed() {
  [ -f "$HOME/Library/Fonts/MesloLGS NF Regular.ttf" ] ||
    [ -f "/Library/Fonts/MesloLGS NF Regular.ttf" ] ||
    [ -f "/System/Library/Fonts/MesloLGS NF Regular.ttf" ]
}

echo "==> Required commands"
for cmd in chezmoi git zsh aws node; do
  require_command "$cmd"
done

if [ "$os_name" = "Darwin" ]; then
  require_command brew
else
  check_command brew
fi

if have_command code; then
  ok "code: $(command -v code)"
else
  warn "code CLI not found; in VS Code run: Shell Command: Install 'code' command in PATH"
fi

if { have_command brew && [ -s "$(brew --prefix 2>/dev/null)/opt/nvm/nvm.sh" ]; } || [ -s "$HOME/.nvm/nvm.sh" ]; then
  ok "nvm is installed"
else
  fail "nvm is not installed"
fi

echo ""
echo "==> Shell and prompt"
if [ "${SHELL:-}" = "$(command -v zsh 2>/dev/null || true)" ]; then
  ok "login shell is zsh"
else
  warn "login shell is ${SHELL:-unset}; expected $(command -v zsh 2>/dev/null || echo zsh)"
fi

if [ -f "$HOME/.p10k.zsh" ]; then
  ok "Powerlevel10k config exists"
else
  fail "~/.p10k.zsh is missing"
fi

if [ "$os_name" != "Darwin" ]; then
  warn "MesloLGS NF font check skipped on $os_name"
elif meslo_font_installed; then
  ok "MesloLGS NF font is installed"
else
  warn "MesloLGS NF font not found; run brew bundle to install font-meslo-for-powerlevel10k"
fi

echo ""
echo "==> 1Password"
if ! have_command op; then
  warn "op not found; install 1Password CLI or run brew bundle"
elif run_with_timeout 5 op whoami >/dev/null 2>&1; then
  ok "1Password CLI is authenticated"
else
  warn "1Password CLI is not authenticated or desktop integration is unavailable"
fi

echo ""
echo "==> AWS"
if aws configure list-profiles 2>/dev/null | grep -qx "${AWS_PROFILE:-work-poweruser}"; then
  ok "AWS profile exists: ${AWS_PROFILE:-work-poweruser}"
else
  warn "AWS profile not found: ${AWS_PROFILE:-work-poweruser}"
fi

if run_with_timeout 10 aws sts get-caller-identity >/dev/null 2>&1; then
  ok "AWS credentials are active"
else
  warn "AWS credentials are not active; run aws sso login --profile ${AWS_PROFILE:-work-poweruser}"
fi

echo ""
echo "==> macOS apps"
if [ "$os_name" = "Darwin" ]; then
  for app in "1Password" "iTerm" "Visual Studio Code" "Warp" "Docker"; do
    if [ -d "/Applications/$app.app" ]; then
      ok "$app.app installed"
    else
      warn "$app.app not found in /Applications"
    fi
  done
fi

echo ""
echo "==> Docker"
if have_command docker && run_with_timeout 5 docker info >/dev/null 2>&1; then
  ok "Docker engine is running"
else
  warn "Docker engine is not running; start Docker Desktop before docker-based tests"
fi

echo ""
if [ "$failures" -gt 0 ]; then
  printf 'FAILED: %s failure(s), %s warning(s)\n' "$failures" "$warnings"
  exit 1
fi

printf 'PASSED: 0 failures, %s warning(s)\n' "$warnings"
