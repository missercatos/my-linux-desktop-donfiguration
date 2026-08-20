# dotfiles

GNU Stow-managed dotfiles for Arch Linux (Hyprland + niri). Default shell: **fish** with vi mode. Zsh available as alternative.

## 一键安装

```bash
./install.sh
```

脚本会依次：安装官方/archlinuxcn 仓库软件（含 `noctalia-qs`，即 dms 用的 quickshell）→ 安装 AUR 软件（无 AUR 助手时自动装 yay）→ 若检测到 `qs` 与 qt6-base 版本不匹配（`symbol lookup error`）则自动从 AUR 重建 `quickshell-git` → `chsh` 切换到 fish → 用 Stow 将全部配置移植到 `~`（含 `/etc/sddm.conf`）→ 修正 `~/.xprofile` 归属 → 重载 niri 配置。

> **qs 符号错误排查**：`qt6-base` 升级后 `dms ipc ...`（如 Mod+Z 应用启动器）可能报
> `qs: symbol lookup error ... QUntypedPropertyBinding`，原因是 archlinuxcn 预编译的
> `noctalia-qs` 未跟上 qt6-base 版本。直接重跑 `./install.sh` 会自动重建；或手动：
> `sudo pacman -Rdd noctalia-qs && yay -S --aur quickshell-git`。

## 中文化

- **man 手册**：安装 `man-pages-zh_cn`，`MANPATH=/usr/share/man/zh_CN:`（fish `config.fish` 与 `environment.d/locale.conf` 中配置，尾部冒号追加默认路径）。
- **`-h`/`--help` 中文**：`fish/.config/fish/functions/*.fish` 是 70+ 个包装函数，拦截 `-h`/`--help` 输出 `fish/.config/fish/zhhelp/*.txt` 的中文解释（未收录的命令自动回落到英文原帮助）。新增工具时：写 `zhhelp/<工具>.txt` + 复制任意现有包装函数改名即可。
- **GNU 工具 `--help`**：`LANG/LANGUAGE=zh_CN.UTF-8` 已配置（`environment.d/locale.conf`），coreutils 等 gettext 工具直接输出中文。

## Packages

| Package | Target | Description |
|---|---|---|
| `niri` | `~/.config/niri/` | Niri compositor config (modular KDL) |
| `hyprland` | `~/.config/hypr/` | Hyprland config (mirrors niri behavior) |
| `nvim` | `~/.config/nvim/` | Neovim config (ARKVIM + LazyVim, 注释色已加亮 `#9aa5d8`) |
| `kitty` | `~/.config/kitty/` | Kitty terminal（`bright.conf` 加亮：前景 `#f8f6ee`、背景加深 `#05060c`、color8 提亮 `#cbc7ba`，vim 注释随之变亮但仍暗于正文；不随 DMS 主题覆盖） |
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
| `bin` | `~/.local/bin/` | User scripts (trav 值空间遍历/爆破 · gitdump .git 泄露恢复 · githack Python3 版 GitHack · svndump SVN 泄露利用 · hgdump HG(Mercurial) 泄露利用 · dsstore .DS_Store 解析, 37+ scripts) |

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

> 推荐直接用 `./install.sh` 代替上面的手工流程。

## Notes

- **Fish** is the default shell with vi mode (`fish_vi_key_bindings`). Mode indicator hidden to keep starship clean.
- **Zsh** is available as alternative with vi mode (`bindkey -v`), `jk`/`kj` to exit insert mode, and dynamic syntax highlighting colors synced from cava/Matugen.
- `.xprofile` is root-owned; fix with `sudo chown a:a ~/.xprofile` before stowing.
- `sddm` package uses `--target=/` to place `/etc/sddm.conf`.
- `starship.toml.custom` is the backup; Matugen generates `starship.toml` at runtime.
- Machine-specific files **not included**: `kwinoutputconfig.json`, `plasma-org.kde.plasma.desktop-appletsrc`.
- Nested `.git` dirs exist in some `plasma-theme` splash themes — manage with `.gitignore` or submodules.
- Some `bin/` scripts are Arch Linux-specific (pacman wrappers); portable scripts are mixed in.
