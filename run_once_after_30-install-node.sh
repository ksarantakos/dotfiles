#!/bin/sh
set -eu

# Load nvm
NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [ -s "$(brew --prefix)/opt/nvm/nvm.sh" ]; then
  . "$(brew --prefix)/opt/nvm/nvm.sh"
else
  echo "nvm not found, skipping Node install" >&2
  exit 0
fi

nvm install 24
nvm alias default 24
