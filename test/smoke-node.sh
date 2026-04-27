#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

home_dir="$workdir/home"
nvm_dir="$workdir/nvm"
log_file="$workdir/nvm.log"
mkdir -p "$home_dir" "$nvm_dir"

cat >"$nvm_dir/nvm.sh" <<'EOF'
nvm() {
  printf 'nvm %s\n' "$*" >>"$TEST_LOG"
}
EOF

cat >"$home_dir/.npmrc" <<'EOF'
registry=https://registry.npmjs.org/
prefix=/usr/local
//registry.npmjs.org/:_authToken=token
globalconfig=/etc/npmrc
EOF

env HOME="$home_dir" NVM_DIR="$nvm_dir" TEST_LOG="$log_file" PATH="/usr/bin:/bin" \
  sh "$repo_root/run_once_after_30-install-node.sh"

if grep -Eq '^(prefix|globalconfig)=' "$home_dir/.npmrc"; then
  echo "Expected prefix/globalconfig to be removed from .npmrc" >&2
  cat "$home_dir/.npmrc" >&2
  exit 1
fi

for line in \
  "registry=https://registry.npmjs.org/" \
  "//registry.npmjs.org/:_authToken=token"; do
  if ! grep -Fqx "$line" "$home_dir/.npmrc"; then
    echo "Expected npmrc line to be preserved: $line" >&2
    cat "$home_dir/.npmrc" >&2
    exit 1
  fi
done

backup_file="$home_dir/.config/npm-backups/npmrc.pre-nvm"
if [ ! -f "$backup_file" ]; then
  echo "Expected npmrc backup at $backup_file" >&2
  exit 1
fi

for line in \
  "prefix=/usr/local" \
  "globalconfig=/etc/npmrc"; do
  if ! grep -Fqx "$line" "$backup_file"; then
    echo "Expected backup line: $line" >&2
    cat "$backup_file" >&2
    exit 1
  fi
done

for line in \
  "nvm install 24" \
  "nvm use 24" \
  "nvm alias default 24"; do
  if ! grep -Fqx "$line" "$log_file"; then
    echo "Expected nvm call: $line" >&2
    cat "$log_file" >&2
    exit 1
  fi
done

echo "Node bootstrap smoke test passed"
