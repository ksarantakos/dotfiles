#!/bin/bash
set -eu

if ! command -v code >/dev/null 2>&1; then
  echo "VS Code CLI (code) not found, skipping VS Code setup" >&2
  exit 0
fi

# Install Tokyo Night theme extension
code --install-extension enkia.tokyo-night --force

# Merge vscode/settings.json and vscode/tokyo-night-v2.json into the VS Code user settings
settings_dir="$HOME/Library/Application Support/Code/User"
mkdir -p "$settings_dir"

repo_dir="$(cd "$(dirname "$0")" && pwd)"

python3 - <<PYEOF
import json, pathlib

settings_path = pathlib.Path("$settings_dir/settings.json")
base = json.loads(settings_path.read_text()) if settings_path.exists() else {}

settings = json.loads(pathlib.Path("$repo_dir/vscode/settings.json").read_text())
colors   = json.loads(pathlib.Path("$repo_dir/vscode/tokyo-night-v2.json").read_text())

base.update(settings)
base["workbench.colorCustomizations"] = {
    **base.get("workbench.colorCustomizations", {}),
    **colors
}

settings_path.write_text(json.dumps(base, indent=2) + "\n")
print("VS Code settings written to", settings_path)
PYEOF
