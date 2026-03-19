#!/bin/sh
set -eu

if ! command -v op >/dev/null 2>&1; then
  exit 0
fi

if perl -e 'alarm 5; exec @ARGV' op whoami >/dev/null 2>&1; then
  echo yes
fi
