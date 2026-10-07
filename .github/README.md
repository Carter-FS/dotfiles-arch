# dotfiles-arch

Personal configuration dotfiles for my Arch Linux environment, layered on top of [Omarchy](https://omarchy.org).

## What's included

- `.bashrc` - aliases and helpers on top of the Omarchy bash defaults
- `.config/starship.toml` - prompt configuration
- `.config/waybar/` - status bar layout and styling, with custom widgets:
  - `scripts/pomodoro.sh` - Pomodoro timer with skip, reset and a settings menu
  - `scripts/vpn.sh` - ProtonVPN (WireGuard) status and click-to-toggle
- `.gitconfig` - git defaults and aliases
- `.commit-conventions.txt` - commit message template

## Requirements

- [Omarchy](https://omarchy.org) (the waybar style imports the active Omarchy theme, and `.bashrc` sources Omarchy's defaults)
- CaskaydiaMono Nerd Font
- For the VPN widget: `wireguard-tools`, a `/etc/wireguard/proton-au.conf` tunnel and a NOPASSWD sudoers rule for `wg-quick up/down proton-au`

## Setup

The dotfiles are managed as a bare git repository with `$HOME` as the work tree.

```bash
git clone --bare git@github.com:Carter-FS/dotfiles-arch.git $HOME/dotfiles-arch
alias config='/usr/bin/git --git-dir=$HOME/dotfiles-arch/ --work-tree=$HOME'
config config --local status.showUntrackedFiles no
config checkout
```

If `checkout` complains about existing files, back them up or remove them and run it again. After that, use `config` like `git`, for example `config pull` or `config add ~/.bashrc`.

## Credits

- [Omarchy](https://github.com/basecamp/omarchy) by Basecamp - the base desktop configuration and default waybar layout this setup extends (MIT)
- [Atlassian bare repo dotfiles guide](https://www.atlassian.com/git/tutorials/dotfiles)

## Licence

Released under the MIT licence (see `LICENSE`).
