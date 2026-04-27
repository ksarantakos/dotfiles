#!/bin/sh
set -eu

custom_plugins_dir="$HOME/.oh-my-zsh/custom/plugins"

mkdir -p "$custom_plugins_dir"

install_plugin() {
  plugin_name="$1"
  plugin_repo="$2"
  plugin_dir="$custom_plugins_dir/$plugin_name"

  if [ ! -d "$plugin_dir" ]; then
    git clone --depth=1 "$plugin_repo" "$plugin_dir"
  fi
}

install_plugin "zsh-autosuggestions" "https://github.com/zsh-users/zsh-autosuggestions.git"
install_plugin "zsh-syntax-highlighting" "https://github.com/zsh-users/zsh-syntax-highlighting.git"
