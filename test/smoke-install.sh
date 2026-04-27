#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

bin_dir="$workdir/bin"
mkdir -p "$bin_dir"
bin_with_gh_dir="$workdir/bin-with-gh"
mkdir -p "$bin_with_gh_dir"
home_dir="$workdir/home"
mkdir -p "$home_dir"
bash_env_file="$workdir/bash_env"

cat >"$bin_dir/chezmoi" <<'EOF'
#!/bin/sh
printf 'chezmoi %s\n' "$*" >>"$TEST_LOG"
EOF

chmod +x "$bin_dir/chezmoi"
cp "$bin_dir/chezmoi" "$bin_with_gh_dir/chezmoi"
chmod +x "$bin_with_gh_dir/chezmoi"

assert_contains() {
  pattern=$1
  file=$2

  if ! grep -Fqx "$pattern" "$file"; then
    echo "Expected line not found: $pattern" >&2
    echo "Captured log:" >&2
    cat "$file" >&2
    exit 1
  fi
}

assert_not_contains() {
  pattern=$1
  file=$2

  if grep -Fqx "$pattern" "$file"; then
    echo "Unexpected line found: $pattern" >&2
    echo "Captured log:" >&2
    cat "$file" >&2
    exit 1
  fi
}

run_case() {
  answer=$1
  log_file=$2
  path_dir=${3:-$bin_dir}
  gh_mode=${4:-default}

  : >"$bash_env_file"
  if [ "$gh_mode" = "absent" ]; then
    cat >"$bash_env_file" <<'EOF'
command() {
  if [ "$1" = "-v" ] && [ "$2" = "gh" ]; then
    return 1
  fi
  builtin command "$@"
}
EOF
  fi

  printf '%s\n' "$answer" |
    env PATH="$path_dir:$PATH" TEST_LOG="$log_file" HOME="$home_dir" BASH_ENV="$bash_env_file" \
    bash "$repo_root/install.sh" >/dev/null
}

OS="$(uname -s)"

if [ "$OS" = "Darwin" ]; then
  cat >"$bin_dir/brew" <<'EOF'
#!/bin/sh
printf 'brew %s\n' "$*" >>"$TEST_LOG"
EOF
  cat >"$bin_dir/op" <<'EOF'
#!/bin/sh
printf 'op %s\n' "$*" >>"$TEST_LOG"
EOF
  chmod +x "$bin_dir/brew" "$bin_dir/op"

  yes_log="$workdir/yes.log"
  run_case "y" "$yes_log"

  assert_contains "brew install --cask 1password" "$yes_log"
  assert_contains "brew install --cask 1password-cli" "$yes_log"
  assert_contains "brew install chezmoi" "$yes_log"
  assert_contains "op signin" "$yes_log"
  assert_contains "chezmoi init --branch master --apply https://github.com/ksarantakos/dotfiles" "$yes_log"
  assert_contains "brew bundle --file $home_dir/.local/share/chezmoi/Brewfile" "$yes_log"
  assert_contains "chezmoi apply" "$yes_log"

  no_log="$workdir/no.log"
  run_case "n" "$no_log"

  assert_contains "brew install --cask 1password" "$no_log"
  assert_contains "brew install --cask 1password-cli" "$no_log"
  assert_contains "brew install chezmoi" "$no_log"
  assert_not_contains "op signin" "$no_log"
  assert_contains "chezmoi init --branch master --apply https://github.com/ksarantakos/dotfiles" "$no_log"
  assert_contains "brew bundle --file $home_dir/.local/share/chezmoi/Brewfile" "$no_log"
  assert_contains "chezmoi apply" "$no_log"

elif [ "$OS" = "Linux" ]; then
  cat >"$bin_dir/sudo" <<'EOF'
#!/bin/sh
printf 'sudo %s\n' "$*" >>"$TEST_LOG"
EOF
  cat >"$bin_dir/curl" <<'EOF'
#!/bin/sh
printf 'curl %s\n' "$*" >>"$TEST_LOG"
EOF
  cat >"$bin_dir/dpkg" <<'EOF'
#!/bin/sh
[ "$1" = "--print-architecture" ] && echo "amd64"
printf 'dpkg %s\n' "$*" >>"$TEST_LOG"
EOF
  chmod +x "$bin_dir/sudo" "$bin_dir/curl" "$bin_dir/dpkg"
  cp "$bin_dir/sudo" "$bin_with_gh_dir/sudo"
  cp "$bin_dir/curl" "$bin_with_gh_dir/curl"
  cp "$bin_dir/dpkg" "$bin_with_gh_dir/dpkg"
  cat >"$bin_with_gh_dir/gh" <<'EOF'
#!/bin/sh
exit 0
EOF
  chmod +x "$bin_with_gh_dir/sudo" "$bin_with_gh_dir/curl" "$bin_with_gh_dir/dpkg" "$bin_with_gh_dir/gh"

  # Pre-populate apt-packages.txt so the bulk-install path is exercised
  mkdir -p "$home_dir/.local/share/chezmoi"
  printf 'gnupg\npandoc\n' > "$home_dir/.local/share/chezmoi/apt-packages.txt"

  yes_log="$workdir/yes.log"
  run_case "y" "$yes_log" "$bin_dir" "absent"

  # op is not installed on Linux — should skip signin even when user answers y
  assert_contains "sudo env DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get update -qq" "$yes_log"
  assert_contains "sudo env DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install -y curl git zsh build-essential" "$yes_log"
  assert_not_contains "op signin" "$yes_log"
  assert_contains "chezmoi init --branch master --apply https://github.com/ksarantakos/dotfiles" "$yes_log"
  # bulk apt-get install from packages file
  assert_contains "sudo env DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install -y gnupg pandoc" "$yes_log"
  # gh install via official apt repo
  assert_contains "curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg" "$yes_log"
  assert_contains "sudo env DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install -y gh" "$yes_log"
  # eza best-effort install
  assert_contains "sudo env DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install -y eza" "$yes_log"
  assert_contains "chezmoi apply" "$yes_log"
  assert_not_contains "brew install chezmoi" "$yes_log"

  no_log="$workdir/no.log"
  run_case "n" "$no_log" "$bin_with_gh_dir" "default"

  assert_contains "sudo env DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get update -qq" "$no_log"
  assert_contains "sudo env DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install -y curl git zsh build-essential" "$no_log"
  assert_not_contains "op signin" "$no_log"
  assert_contains "chezmoi init --branch master --apply https://github.com/ksarantakos/dotfiles" "$no_log"
  assert_contains "sudo env DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install -y gnupg pandoc" "$no_log"
  assert_not_contains "curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg" "$no_log"
  assert_not_contains "sudo env DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install -y gh" "$no_log"
  assert_contains "sudo env DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install -y eza" "$no_log"
  assert_contains "chezmoi apply" "$no_log"
  assert_not_contains "brew install chezmoi" "$no_log"

else
  echo "Unsupported OS for smoke test: $OS" >&2
  exit 1
fi

echo "install.sh smoke test passed"
