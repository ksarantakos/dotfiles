#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

bin_dir="$workdir/bin"
mkdir -p "$bin_dir"
home_dir="$workdir/home"
mkdir -p "$home_dir"

cat >"$bin_dir/brew" <<'EOF'
#!/bin/sh
printf 'brew %s\n' "$*" >>"$TEST_LOG"
EOF

cat >"$bin_dir/chezmoi" <<'EOF'
#!/bin/sh
printf 'chezmoi %s\n' "$*" >>"$TEST_LOG"
EOF

cat >"$bin_dir/op" <<'EOF'
#!/bin/sh
printf 'op %s\n' "$*" >>"$TEST_LOG"
EOF

chmod +x "$bin_dir/brew" "$bin_dir/chezmoi" "$bin_dir/op"

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

  printf '%s\n' "$answer" |
    env PATH="$bin_dir:$PATH" TEST_LOG="$log_file" HOME="$home_dir" \
    bash "$repo_root/install.sh" >/dev/null
}

yes_log="$workdir/yes.log"
run_case "y" "$yes_log"

assert_contains "brew install chezmoi" "$yes_log"
assert_contains "brew install --cask 1password-cli" "$yes_log"
assert_contains "op signin" "$yes_log"
assert_contains "chezmoi init --apply https://github.com/ksarantakos/dotfiles" "$yes_log"
assert_contains "brew bundle --file $home_dir/.local/share/chezmoi/Brewfile" "$yes_log"
assert_contains "chezmoi apply" "$yes_log"

no_log="$workdir/no.log"
run_case "n" "$no_log"

assert_contains "brew install chezmoi" "$no_log"
assert_contains "brew install --cask 1password-cli" "$no_log"
assert_not_contains "op signin" "$no_log"
assert_contains "chezmoi init --apply https://github.com/ksarantakos/dotfiles" "$no_log"
assert_contains "brew bundle --file $home_dir/.local/share/chezmoi/Brewfile" "$no_log"
assert_contains "chezmoi apply" "$no_log"

echo "install.sh smoke test passed"
