#!/bin/sh
set -eu

theme_dir="$HOME/.oh-my-zsh/custom/themes/powerlevel10k"

if [ ! -d "$theme_dir" ]; then
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$theme_dir"
fi
