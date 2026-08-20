#!/usr/bin/env bash
# =============================================================
# 一键安装脚本：安装所需软件 + 通过 GNU Stow 移植全部配置
# 用法: ./install.sh
# 依赖: 已登录 sudo（脚本会请求一次密码）
# =============================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_NAME="${SUDO_USER:-$USER}"

info() { printf '\033[1;32m[install]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warning]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

command -v sudo >/dev/null || die "未找到 sudo"

# -------------------------------------------------------------
# 1. 安装官方/archlinuxcn 仓库软件
# -------------------------------------------------------------
OFFICIAL_PKGS=(
    # 桌面栈
    niri kitty fish neovim stow dms-shell dms-shell-niri
    noctalia-qs base-devel
    starship fastfetch cava btop yazi fuzzel foot alacritty
    eza bat zoxide tmux fzf ripgrep fd
    # 工具
    git gnupg openssh curl wget rsync gzip xz zip unzip 7zip
    imagemagick ffmpeg jq sqlite openssl gdb tldr
    coreutils findutils sed grep procps-ng util-linux iproute2
    nodejs yt-dlp docker mpv wl-clipboard wireplumber networkmanager
    # zsh 备选
    zsh zsh-syntax-highlighting zsh-autosuggestions zsh-autocomplete zsh-completions
    # 中文 man 手册
    man-pages-zh_cn
)
info "安装官方/archlinuxcn 仓库软件 ..."
sudo pacman -S --needed --noconfirm "${OFFICIAL_PKGS[@]}"

# -------------------------------------------------------------
# 2. AUR 软件（dms 相关）
# -------------------------------------------------------------
AUR_PKGS=(
    niri-sidebar-git
    shorin-dms-niri-git
    shorin-contrib-git
    shorin-screenrec-menu-git
)

AUR_HELPER=""
command -v yay  >/dev/null && AUR_HELPER=yay
command -v paru >/dev/null && AUR_HELPER=paru
if [[ -z "$AUR_HELPER" ]]; then
    info "未找到 AUR 助手，正在安装 yay ..."
    sudo pacman -S --needed --noconfirm base-devel git
    git clone https://aur.archlinux.org/yay.git /tmp/opencode/yay-build
    (cd /tmp/opencode/yay-build && makepkg -si --noconfirm)
    AUR_HELPER=yay
fi
info "通过 $AUR_HELPER 安装 AUR 软件 ..."
"$AUR_HELPER" -S --needed --noconfirm "${AUR_PKGS[@]}"

# -------------------------------------------------------------
# 2.1 修复 qs 与 qt6-base 版本不匹配
#     archlinuxcn 预编译的 noctalia-qs 在 qt6-base 升级后可能
#     出现 "symbol lookup error ... QUntypedPropertyBinding"，
#     此时从 AUR 源码重建 quickshell-git 适配当前 qt6-base。
# -------------------------------------------------------------
if command -v qs >/dev/null && qs --version 2>&1 | grep -q "symbol lookup error"; then
    warn "检测到 qs 与 qt6-base 版本不匹配，从 AUR 重建 quickshell-git（耗时较长）..."
    sudo pacman -Rdd --noconfirm noctalia-qs 2>/dev/null || true
    if "$AUR_HELPER" -S --noconfirm --aur quickshell-git; then
        info "quickshell-git 重建完成"
    else
        warn "自动重建失败，请手动执行：yay -S --aur quickshell-git"
    fi
fi

# -------------------------------------------------------------
# 3. 设置默认 shell 为 fish
# -------------------------------------------------------------
if [[ "$(getent passwd "$USER_NAME" | cut -d: -f7)" != "/usr/bin/fish" ]]; then
    info "设置默认 shell 为 fish ..."
    sudo chsh -s /usr/bin/fish "$USER_NAME"
fi

# -------------------------------------------------------------
# 4. Stow 移植配置
# -------------------------------------------------------------
cd "$REPO_DIR"
info "通过 GNU Stow 移植配置到 \$HOME ..."
for pkg in */; do
    pkg="${pkg%/}"
    case "$pkg" in
        .git|sddm) continue ;;
    esac
    if [[ -d "$pkg" ]]; then
        stow --restow "$pkg"
    fi
done

# 特殊项: /etc 下的配置
if [[ -f sddm/etc/sddm.conf ]]; then
    info "移植 sddm 配置到 /etc ..."
    sudo stow --target=/ --restow sddm
fi

# 特殊项: ~/.xprofile 若为 root 所有则修正归属
if [[ -e "$HOME/.xprofile" && "$(stat -c %U "$HOME/.xprofile")" = "root" ]]; then
    info "修正 ~/.xprofile 归属 ..."
    sudo chown "$USER_NAME":"$USER_NAME" "$HOME/.xprofile"
fi

# -------------------------------------------------------------
# 5. 收尾
# -------------------------------------------------------------
if command -v niri >/dev/null && pgrep -x niri >/dev/null; then
    info "niri 正在运行，重载配置 ..."
    niri msg action reload-config || warn "niri 重载失败，请手动执行 niri msg action reload-config"
fi

info "全部完成。默认 shell 为 fish，man 手册为中文（MANPATH 已配置）。"