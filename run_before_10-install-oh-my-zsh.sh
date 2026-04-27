#!/bin/sh
set -eu

oh_my_zsh_dir="$HOME/.oh-my-zsh"

if [ ! -d "$oh_my_zsh_dir" ]; then
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi
