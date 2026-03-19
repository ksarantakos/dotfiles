#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

bin_dir="$workdir/bin"
mkdir -p "$bin_dir"
home_dir="$workdir/home"
mkdir -p "$home_dir"
log_file="$workdir/vscode.log"

# Stub code CLI
cat >"$bin_dir/code" <<'EOF'
#!/bin/sh
printf 'code %s\n' "$*" >>"$TEST_LOG"
EOF
chmod +x "$bin_dir/code"

# Render the template manually (substitute chezmoi.sourceDir)
rendered="$workdir/run_once_after_40-configure-vscode.sh"
sed "s|{{ .chezmoi.sourceDir }}|$repo_root|g" \
  "$repo_root/run_once_after_40-configure-vscode.sh.tmpl" > "$rendered"

# Run the rendered script
env PATH="$bin_dir:$PATH" TEST_LOG="$log_file" HOME="$home_dir" \
  bash "$rendered" >/dev/null

# Extension install was called
if ! grep -Fqx "code --install-extension enkia.tokyo-night --force" "$log_file"; then
  echo "Expected: code --install-extension enkia.tokyo-night --force" >&2
  echo "Captured log:" >&2
  cat "$log_file" >&2
  exit 1
fi

# settings.json was written and contains expected keys
settings_file="$home_dir/Library/Application Support/Code/User/settings.json"
if [ ! -f "$settings_file" ]; then
  echo "settings.json was not written to $settings_file" >&2
  exit 1
fi

for key in "workbench.colorTheme" "workbench.colorCustomizations"; do
  if ! grep -q "\"$key\"" "$settings_file"; then
    echo "Missing key in settings.json: $key" >&2
    cat "$settings_file" >&2
    exit 1
  fi
done

# Existing settings are preserved on re-run
printf '{"my.existing.setting": true}\n' > "$settings_file"
env PATH="$bin_dir:$PATH" TEST_LOG="$log_file" HOME="$home_dir" \
  bash "$rendered" >/dev/null

if ! grep -q '"my.existing.setting"' "$settings_file"; then
  echo "Existing settings were lost on re-run" >&2
  cat "$settings_file" >&2
  exit 1
fi

# Capture absolute paths before any PATH manipulation
bash_bin=$(command -v bash)
python3_bin=$(command -v python3)

# Missing code CLI: script should exit 0 (graceful skip) with a "not found" message.
# PATH is fully isolated — only python3 is available — so code cannot be found via inheritance.
no_code_bin="$workdir/no-code-bin"
mkdir -p "$no_code_bin"
ln -s "$python3_bin" "$no_code_bin/python3"

no_code_stderr="$workdir/no-code.stderr"
exit_code=0
env PATH="$no_code_bin" TEST_LOG="/dev/null" HOME="$home_dir" \
  "$bash_bin" "$rendered" >/dev/null 2>"$no_code_stderr" || exit_code=$?

if [ "$exit_code" -ne 0 ]; then
  echo "Expected exit 0 when code is missing, got $exit_code" >&2
  exit 1
fi
if ! grep -q "not found" "$no_code_stderr"; then
  echo "Expected 'not found' message in stderr when code is missing" >&2
  cat "$no_code_stderr" >&2
  exit 1
fi

# Missing python3: script should exit non-zero with a "python3 not found" message,
# confirming the guard was reached (not some earlier failure).
# PATH is fully isolated — only code stub is available.
no_python_bin="$workdir/no-python-bin"
mkdir -p "$no_python_bin"
cp "$bin_dir/code" "$no_python_bin/code"

no_python_stderr="$workdir/no-python.stderr"
exit_code=0
env PATH="$no_python_bin" TEST_LOG="/dev/null" HOME="$home_dir" \
  "$bash_bin" "$rendered" >/dev/null 2>"$no_python_stderr" || exit_code=$?

if [ "$exit_code" -eq 0 ]; then
  echo "Expected non-zero exit when python3 is missing" >&2
  exit 1
fi
if ! grep -q "python3 not found" "$no_python_stderr"; then
  echo "Expected 'python3 not found' in stderr — guard may not have been reached" >&2
  cat "$no_python_stderr" >&2
  exit 1
fi

echo "VS Code smoke test passed"
