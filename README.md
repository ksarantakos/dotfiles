# dotfiles

Personal dotfiles managed with [chezmoi](https://chezmoi.io) and [1Password](https://1password.com) for secrets.

## How this repo works

This repo is the source of truth for machine setup. `chezmoi apply` does three things:

- renders tracked dotfiles into `$HOME`
- fills secret-backed templates from 1Password
- runs one-time bootstrap scripts for tools that need extra setup

When 1Password CLI is not authenticated, `chezmoi` will skip `~/.npmrc` so the rest of the repo
can still apply cleanly.

## What's managed

| File | Description |
|------|-------------|
| `~/.zshrc` | Zsh shell config (oh-my-zsh, pyenv, powerlevel10k) |
| `~/.zprofile` | Brew shellenv |
| `~/.gitconfig` | Git user config, SSH signing |
| `~/.ssh/config` | SSH host config + 1Password agent |
| `~/.config/iterm2/com.googlecode.iterm2.plist` | Full iTerm2 preferences loaded from a custom prefs folder |
| `~/.p10k.zsh` | Powerlevel10k prompt theme |
| `~/.npmrc` | NPM registry config (token fetched from 1Password) |
| `~/.yarnrc` | Yarn config |
| `Brewfile` | Homebrew packages and casks tracked in the chezmoi source dir |
| `run_once_after_*` | One-time setup hooks for tools that need post-apply configuration |

## Bootstrap a new machine

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/ksarantakos/dotfiles/master/install.sh)"
```

The script will:

1. Install Homebrew if not present
2. Install chezmoi and the 1Password CLI
3. Optionally sign in to 1Password (only needed for access to the private NBC News Nexus NPM registry)
4. Pull and apply dotfiles (including Oh My Zsh install)
5. Install all Homebrew packages, casks, and fonts (including Meslo for Powerlevel10k)
6. Re-apply so post-install hooks run (Powerlevel10k, iTerm2 prefs)

Open a new shell after it completes.

On Linux, if your login shell is still not `zsh` after bootstrap, run:

```sh
chsh -s "$(command -v zsh)"
```

Then log out and back in so the shell change takes effect.

If you skipped 1Password sign-in and later need access to the private NBC News Nexus NPM registry:

```sh
op signin
chezmoi apply
```

That will render `~/.npmrc` with the Nexus registry and auth token.

## Secrets and 1Password

Files with a `.tmpl` extension are chezmoi templates. Secrets are never stored in git — they are
read from 1Password at apply time using the `onepasswordRead` function.

Example template syntax used in `dot_npmrc.tmpl`:

```
{{ onepasswordRead "op://VaultName/ItemName/field" }}
```

If `op whoami` fails, `chezmoi` ignores `~/.npmrc` until 1Password is available again.

To add a new secret-bearing dotfile:

```sh
# 1. Store the secret in 1Password
op item create --category="API Credential" --title="My Token" --vault="Private" "credential[password]=mysecret"

# 2. Add the file as a template (note the --template flag)
chezmoi add --template ~/.my-config-file

# 3. Replace the secret value in the template with an op reference
chezmoi edit ~/.my-config-file
# e.g. token={{ onepasswordRead "op://Private/My Token/credential" }}
```

## Daily workflow

Edit through chezmoi:

```sh
chezmoi edit ~/.zshrc
chezmoi apply
```

If you changed a live file directly, sync it back:

```sh
chezmoi re-add ~/.zshrc
chezmoi re-add ~/.p10k.zsh
chezmoi re-add ~/.config/iterm2/com.googlecode.iterm2.plist
```

Preview pending changes:

```sh
chezmoi diff
```

Apply the repo state:

```sh
chezmoi apply
```

Commit and push:

```sh
chezmoi git -- add -A
chezmoi git -- commit -m "your message"
chezmoi git -- push
```

## Add a new dotfile

```sh
chezmoi add ~/.my-new-dotfile
chezmoi git -- add -A
chezmoi git -- commit -m "add my-new-dotfile"
chezmoi git -- push
```

## Refresh packages

```sh
brew bundle --file ~/.local/share/chezmoi/Brewfile
brew bundle dump --force --file ~/.local/share/chezmoi/Brewfile
```

## Smoke test

```sh
./test/smoke-install.sh
./test/smoke-node.sh
./test/smoke-vscode.sh
```

These verify the bootstrap command flow, Node/nvm npmrc handling, and VS Code setup without touching the network or real Homebrew state.
