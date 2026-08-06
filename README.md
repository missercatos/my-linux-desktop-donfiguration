# dotfiles

GNU Stow-managed dotfiles for Arch Linux (Hyprland + niri). Default shell: **fish** with vi mode. Zsh available as alternative.

## Packages

| Package | Target | Description |
|---|---|---|
| `niri` | `~/.config/niri/` | Niri compositor config (modular KDL) |
| `hyprland` | `~/.config/hypr/` | Hyprland config (mirrors niri behavior) |
| `nvim` | `~/.config/nvim/` | Neovim config (ARKVIM + LazyVim) |
| `kitty` | `~/.config/kitty/` | Kitty terminal |
| `foot` | `~/.config/foot/` | Foot terminal（战略终端一号：纯黑 + 古早 CRT 绿，zsh 经 ZDOTDIR 完全隔离） |
| `alacritty` | `~/.config/alacritty/` | Alacritty terminal（战略终端二号：与 foot 同套战略配置） |
| `tactical` | `~/.config/tactical/` | 战略终端共享配置（单行磷光绿语义色 starship + 隔离 zsh + 原版 fastfetch `f`） |
| `fish` | `~/.config/fish/` | Fish shell (vi mode, config, aliases, functions) |
| `starship` | `~/.config/starship.toml.custom` | Starship prompt backup (Matugen overwrites `starship.toml`) |
| `zsh` | `~/.zshrc` | Zsh config (vi mode, dynamic colors, autocomplete) |
| `fastfetch` | `~/.config/fastfetch/` | Fastfetch (kitty logo via `a.png`) |
| `cava` | `~/.config/cava/` | Cava audio visualizer |
| `btop` | `~/.config/btop/` | Btop resource monitor |
| `yazi` | `~/.config/yazi/` | Yazi file manager |
| `fuzzel` | `~/.config/fuzzel/` | Fuzzel app launcher |
| `gtk` | `~/.config/gtk-3.0/` + `gtk-4.0/` | GTK theme settings |
| `matugen` | `~/.config/matugen/` | Matugen theme generator (templates for starship, fastfetch, cava, etc.) |
| `fontconfig` | `~/.config/fontconfig/` | Font config (CJK fallback + rendering) |
| `environment` | `~/.config/environment.d/` | Systemd user env (input method) |
| `xprofile` | `~/.xprofile` | X11 session env (needs `sudo chown a:a ~/.xprofile` first) |
| `bash` | `~/.bashrc` | Bash fallback (locale) |
| `fcitx5` | `~/.config/fcitx5/` | Fcitx5 input method |
| `plasma` | `~/.config/` (selected) | KDE Plasma configs (kdeglobals, kwinrc, etc.) |
| `plasma-theme` | `~/.local/share/plasma/` | Plasma desktop theme (Ant-Dark) + splash screens |
| `konsole` | `~/.local/share/konsole/` | Konsole profiles/colorschemes |
| `applications` | `~/.local/share/applications/` | Custom desktop entries |
| `icons` | `~/.local/share/icons/` | Icon themes (Adwaita-Matugen, Klassy, Slot-Beauty-Dark) |
| `sddm` | `/etc/sddm.conf` | SDDM config (needs `sudo stow --target=/ sddm`) |
| `bin` | `~/.local/bin/` | User scripts (trav 值空间遍历/爆破 · gitdump .git 泄露恢复 · githack Python3 版 GitHack · dsstore .DS_Store 解析, 37+ scripts) |

## Bootstrap

```bash
# Install dependencies
sudo pacman -S stow fish zsh zsh-syntax-highlighting zsh-autosuggestions zsh-autocomplete zsh-completions

# Set fish as default shell
chsh -s /usr/bin/fish

# Clone and stow everything
cd ~/dotfiles
for pkg in */; do
  stow -v "${pkg%/}"
done

# Special cases:
sudo chown a:a ~/.xprofile
sudo stow --target=/ sddm
```

## Notes

- **Fish** is the default shell with vi mode (`fish_vi_key_bindings`). Mode indicator hidden to keep starship clean.
- **Zsh** is available as alternative with vi mode (`bindkey -v`), `jk`/`kj` to exit insert mode, and dynamic syntax highlighting colors synced from cava/Matugen.
- `.xprofile` is root-owned; fix with `sudo chown a:a ~/.xprofile` before stowing.
- `sddm` package uses `--target=/` to place `/etc/sddm.conf`.
- `starship.toml.custom` is the backup; Matugen generates `starship.toml` at runtime.
- Machine-specific files **not included**: `kwinoutputconfig.json`, `plasma-org.kde.plasma.desktop-appletsrc`.
- Nested `.git` dirs exist in `nvim/` and some `plasma-theme` splash themes — manage with `.gitignore` or submodules.
- Some `bin/` scripts are Arch Linux-specific (pacman wrappers); portable scripts are mixed in.
