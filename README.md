# dotfiles

Personal dotfiles managed with [chezmoi](https://chezmoi.io) and [1Password](https://1password.com) for secrets.

## What's tracked

| File | Description |
|------|-------------|
| `~/.zshrc` | Zsh shell config (oh-my-zsh, pyenv, starship) |
| `~/.zprofile` | Brew shellenv |
| `~/.gitconfig` | Git user config, SSH signing |
| `~/.ssh/config` | SSH host config + 1Password agent |
| `~/.config/starship.toml` | Starship prompt theme |
| `~/.npmrc` | NPM registry config (token fetched from 1Password) |
| `~/.yarnrc` | Yarn config |
| `~/Brewfile` | Homebrew packages and casks |

## Prerequisites

- [Homebrew](https://brew.sh)
- [chezmoi](https://chezmoi.io): `brew install chezmoi`
- [1Password CLI](https://developer.1password.com/docs/cli): `brew install --cask 1password-cli`
- Sign in to 1Password CLI: `op signin`

## Fresh machine setup

```sh
# 1. Sign in to 1Password CLI
op signin

# 2. Pull and apply all dotfiles in one command
chezmoi init --apply https://github.com/ksarantakos/dotfiles

# 3. Install all Homebrew packages
brew bundle --file ~/.local/share/chezmoi/Brewfile
```

That's it. chezmoi will fetch secrets from 1Password automatically during apply.

## Secrets and 1Password

Files with a `.tmpl` extension are chezmoi templates. Secrets are never stored in git — they are
read from 1Password at apply time using the `onepasswordRead` function.

Example template syntax used in `dot_npmrc.tmpl`:

```
{{ onepasswordRead "op://VaultName/ItemName/field" }}
```

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

## Day-to-day usage

**Edit a dotfile:**
```sh
chezmoi edit ~/.zshrc        # opens in $EDITOR
```

**After editing a dotfile directly** (outside of chezmoi edit):
```sh
chezmoi re-add ~/.zshrc      # syncs changes back into the source directory
```

**Preview what chezmoi would change:**
```sh
chezmoi diff
```

**Apply the latest dotfiles:**
```sh
chezmoi apply
```

**Commit and push changes:**
```sh
cd ~/.local/share/chezmoi
git add -A
git commit -m "your message"
git push
```

Or use the chezmoi shorthand:
```sh
chezmoi git -- add -A
chezmoi git -- commit -m "your message"
chezmoi git -- push
```

## Adding a new dotfile

```sh
chezmoi add ~/.my-new-dotfile
chezmoi git -- add -A
chezmoi git -- commit -m "add my-new-dotfile"
chezmoi git -- push
```

## Keeping packages up to date

```sh
brew bundle --file ~/Brewfile   # install any missing packages
brew bundle dump --force        # overwrite Brewfile with currently installed packages
chezmoi re-add ~/Brewfile
```
