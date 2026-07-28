# dotfiles

GNU Stow-managed dotfiles for Arch Linux (Hyprland + niri).

## Packages

| Package | Target | Description |
|---|---|---|
| `niri` | `~/.config/niri/` | Niri compositor config (modular KDL) |
| `hyprland` | `~/.config/hypr/` | Hyprland config (mirrors niri behavior) |
| `nvim` | `~/.config/nvim/` | Neovim config (ARKVIM + LazyVim) |
| `kitty` | `~/.config/kitty/` | Kitty terminal |
| `fish` | `~/.config/fish/` | Fish shell (config, aliases, functions) |
| `starship` | `~/.config/starship.toml.custom` | Starship prompt backup (Matugen overwrites `starship.toml`) |
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
| `bin` | `~/.local/bin/` | User scripts (37 scripts, some Arch-specific) |

## Bootstrap

```bash
# Install stow
sudo pacman -S stow

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

- `.xprofile` is root-owned; fix with `sudo chown a:a ~/.xprofile` before stowing.
- `sddm` package uses `--target=/` to place `/etc/sddm.conf`.
- `starship.toml.custom` is the backup; Matugen generates `starship.toml` at runtime.
- Machine-specific files **not included**: `kwinoutputconfig.json`, `plasma-org.kde.plasma.desktop-appletsrc`.
- Nested `.git` dirs exist in `nvim/` and some `plasma-theme` splash themes — manage with `.gitignore` or submodules.
- Some `bin/` scripts are Arch Linux-specific (pacman wrappers); portable scripts are mixed in.
