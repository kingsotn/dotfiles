# Linux (Ubuntu 24.04, i3 on X11)

Mirrors the Mac setup (Karabiner + skhd/yabai + iTerm) on a NIZ Plum 68 in factory mode
(bottom row sends Ctrl | Win | Alt; keycaps are Mac order Ctrl | Opt | Cmd).

- `keyd/default.conf` → `/etc/keyd/default.conf`: Caps = Hyper, Cmd acts as Ctrl for shortcuts,
  Opt = Alt, Cmd+1..9 = tab N, Hyper+ijkl arrows, Hyper+Cmd/Opt line/word jumps
- `keyd/app.conf` → `~/.config/keyd/app.conf`: per-app overrides (terminal copy/paste, kitty iTerm keys)
- `i3/` → `~/.config/i3/` (symlinked): Cmd+Tab Mac-style switcher via alttab, Hyper+1/2/3/6/7 focus-or-launch apps like Karabiner `open -a`,
  Opt+ijkl focus, Shift+Opt+wasd move, Shift+Opt+N send to workspace
- `bin/ssh-watch` → `~/.local/bin/` (symlinked): live SSH session monitor, opened with Hyper+4
- `kitty/kitty.conf` → `~/.config/kitty/`: iTerm2 keys (Cmd+D split, Cmd+T tab, Cmd+[ ] panes, ...)
- `.zshrc`, `.xprofile` → `~/`: oh-my-zsh prompt from the Mac + autosuggestions/syntax-highlighting

## Install

```sh
# keyd (not in Ubuntu repos): build latest release
git clone https://github.com/rvaiya/keyd && cd keyd && git checkout "$(git describe --tags --abbrev=0)"
make && sudo make install && sudo systemd-sysusers
sudo apt install -y python3-xlib kitty alttab
sudo usermod -aG keyd "$USER"
sudo cp linux/keyd/default.conf /etc/keyd/default.conf && sudo systemctl enable --now keyd

mkdir -p ~/.config/keyd ~/.config/i3 ~/.config/kitty
cp linux/keyd/app.conf ~/.config/keyd/ && cp linux/i3/* ~/.config/i3/ && cp linux/kitty/kitty.conf ~/.config/kitty/
cp linux/.zshrc linux/.xprofile ~/
mkdir -p ~/.local/bin && ln -sf "$PWD/linux/bin/ssh-watch" ~/.local/bin/ssh-watch
git clone https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
```

Log out and back in (keyd group + app mapper). Emergency keyd kill: Backspace + Escape + Enter.
