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

## Prerequisites

- [Homebrew](https://brew.sh)
- [chezmoi](https://chezmoi.io): `brew install chezmoi`
- [1Password CLI](https://developer.1password.com/docs/cli): `brew install --cask 1password-cli`
- Sign in to 1Password CLI: `op signin`

## Bootstrap a machine

```sh
# 1. Sign in to 1Password
op signin

# 2. Pull and apply dotfiles
chezmoi init --apply https://github.com/ksarantakos/dotfiles

# 3. Install Homebrew packages and casks
brew bundle --file ~/.local/share/chezmoi/Brewfile

# 4. Re-apply once packages are installed
chezmoi apply
```

The second `chezmoi apply` matters. It lets the one-time setup scripts configure tools that may not
exist during the first run, including:

- cloning Powerlevel10k into the Oh My Zsh custom themes directory
- pointing iTerm2 at the tracked custom prefs folder under `~/.config/iterm2`

Open a new shell after that.

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
