# dotfiles

Public Mac setup. Machine-local extras go in `~/.zshrc.local` (gitignored, not in this repo).

## New machine

```sh
xcode-select --install
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"

git clone https://github.com/kingsotn/dotfiles.git ~/dev/dotfiles
cd ~/dev/dotfiles
brew bundle
cp .zshrc ~/.zshrc
cp .zprofile ~/.zprofile
cp .gitconfig ~/.gitconfig
cp .gitignore_global ~/.gitignore_global
```

Then:

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
# re-copy .zshrc after oh-my-zsh overwrites it
cp ~/dev/dotfiles/.zshrc ~/.zshrc
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
nvm install 22
curl -fsSL https://bun.sh/install | bash

gh auth login
cp -R claude/hooks ~/.claude/hooks
cp -R claude/skills ~/.claude/skills
cp claude/CLAUDE.md ~/.claude/CLAUDE.md
cp claude/settings.json ~/.claude/settings.json
cp claude/statusline.sh ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh ~/.claude/hooks/*.sh ~/.claude/hooks/km/*.sh
```

Node comes from nvm, not Homebrew. Do not `brew install node`.

## Layout

- `.zshrc`, `.zprofile`, `Brewfile`, `.gitconfig`
- `claude/` — Claude Code `CLAUDE.md`, skills, hooks, `settings.json`, status line (see `claude/README.md`)
- `karabiner/`, `RectangleConfig.json`, `iterm2_config.json`
- `sketchybar/`, `skhd/`, `yabai/` — leftover tiling-WM configs; current setup uses Rectangle
