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

# Missing code CLI: script should exit 0 and skip setup
no_code_log="$workdir/no-code.log"
if env PATH="$workdir/empty-bin:$PATH" TEST_LOG="$no_code_log" HOME="$home_dir" \
    bash "$rendered" 2>&1 | grep -q "not found"; then
  : # expected
else
  echo "Expected 'not found' message when code is missing" >&2
  exit 1
fi

exit_code=0
env PATH="$workdir/empty-bin:$PATH" TEST_LOG="$no_code_log" HOME="$home_dir" \
  bash "$rendered" >/dev/null 2>/dev/null || exit_code=$?
if [ "$exit_code" -ne 0 ]; then
  echo "Expected exit 0 when code is missing, got $exit_code" >&2
  exit 1
fi

# Missing python3: script should exit non-zero
no_python_bin="$workdir/no-python-bin"
mkdir -p "$no_python_bin"
cp "$bin_dir/code" "$no_python_bin/code"
# Stub python3 as absent by creating a PATH without it but with code
no_python_log="$workdir/no-python.log"
exit_code=0
env PATH="$no_python_bin" TEST_LOG="$no_python_log" HOME="$home_dir" \
  bash "$rendered" >/dev/null 2>/dev/null || exit_code=$?
if [ "$exit_code" -eq 0 ]; then
  echo "Expected non-zero exit when python3 is missing" >&2
  exit 1
fi

echo "VS Code smoke test passed"
