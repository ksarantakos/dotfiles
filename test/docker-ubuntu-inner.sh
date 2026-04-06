#!/usr/bin/env bash
# Runs inside the Ubuntu container. Do not invoke directly — use test/docker-ubuntu.sh.
set -euo pipefail

DISTRO="$(. /etc/os-release && echo "$PRETTY_NAME")"
echo "==> Running on: $DISTRO"
echo ""

# ── Set up a realistic non-root user with passwordless sudo ──────────────────
apt-get update -qq
apt-get install -y --no-install-recommends sudo

useradd -m tester
echo "tester ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/tester
chmod 440 /etc/sudoers.d/tester

# ── Stub chezmoi to skip the GitHub pull ─────────────────────────────────────
# This keeps the test focused on the apt bootstrap, not the dotfile content.
mkdir -p /home/tester/.local/bin
cat > /home/tester/.local/bin/chezmoi << 'EOF'
#!/bin/sh
printf 'chezmoi %s\n' "$*"
EOF
chmod +x /home/tester/.local/bin/chezmoi

# Simulate the apt-packages.txt that chezmoi init --apply would have laid down
mkdir -p /home/tester/.local/share/chezmoi
cp /dotfiles/apt-packages.txt /home/tester/.local/share/chezmoi/apt-packages.txt

chown -R tester: /home/tester/.local

# ── Write the bootstrap command to a file (avoids quoting complexity with su) ─
cat > /tmp/run-install.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
bash /dotfiles/install.sh
EOF
chmod +x /tmp/run-install.sh

# ── Run install.sh as tester (op absent → 1Password prompt auto-skips) ────────
echo "==> Running install.sh as tester..."
echo ""
su - tester -c 'bash /tmp/run-install.sh'

# ── Verify results ────────────────────────────────────────────────────────────
echo ""
echo "==> Verifying installed tools"

fail=false

# Required: must be present after bootstrap
for cmd in git zsh curl; do
  if command -v "$cmd" > /dev/null 2>&1; then
    echo "  [OK]   $cmd  $(command -v "$cmd")"
  else
    echo "  [FAIL] $cmd — not found"
    fail=true
  fi
done

# Optional: available on newer distros only
for cmd in gh eza; do
  if command -v "$cmd" > /dev/null 2>&1; then
    echo "  [OK]   $cmd  $(command -v "$cmd")"
  else
    echo "  [SKIP] $cmd — not available on this distro (expected on 22.04)"
  fi
done

echo ""
$fail && { echo "==> FAILED"; exit 1; } || true
