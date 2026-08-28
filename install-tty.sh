#!/usr/bin/env bash
# =============================================================
# 无图形化界面系统配置脚本
# 仅安装TUI相关配置，荧光绿色系主题
# 用法: ./install-tty.sh
# =============================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_NAME="${SUDO_USER:-$USER}"

info() { printf '\033[1;32m[tty-install]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[tty-warning]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[tty-error]\033[0m %s\n' "$*" >&2; exit 1; }

command -v sudo >/dev/null || die "未找到 sudo"

# -------------------------------------------------------------
# 1. 安装TUI相关软件
# -------------------------------------------------------------
TTY_PKGS=(
    # 终端
    foot tmux zsh
    # Shell增强
    zsh-autocomplete zsh-autosuggestions zsh-syntax-highlighting
    # 文件管理
    yazi eza bat fzf fd ripgrep tree
    # 系统监控
    btop
    # 提示符
    starship
    # 中文支持
    noto-fonts-cjk man-pages-zh_cn
    # 工具
    jq sqlite openssl
    # 开发
    git gh
    # AI工具
    nodejs npm python python3
)

info "安装TUI相关软件 ..."
sudo pacman -S --needed --noconfirm "${TTY_PKGS[@]}"

# -------------------------------------------------------------
# 2. 安装AUR工具
# -------------------------------------------------------------
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

# -------------------------------------------------------------
# 3. 移植foot配置
# -------------------------------------------------------------
info "移植foot配置 ..."
mkdir -p ~/.config/foot
cp "$REPO_DIR/foot/.config/foot/foot.ini" ~/.config/foot/foot.ini

# -------------------------------------------------------------
# 4. 移植tmux配置
# -------------------------------------------------------------
info "移植tmux配置 ..."
cp "$REPO_DIR/tmux/.tmux.conf" ~/.tmux.conf

# -------------------------------------------------------------
# 5. 移植yazi配置
# -------------------------------------------------------------
info "移植yazi配置 ..."
mkdir -p ~/.config/yazi
cp "$REPO_DIR/yazi/.config/yazi/theme.toml" ~/.config/yazi/theme.toml

# -------------------------------------------------------------
# 6. 移植tactical配置（独立绿色主题）
# -------------------------------------------------------------
info "移植tactical配置 ..."
mkdir -p ~/.config/tactical/zsh
cp "$REPO_DIR/tactical/.config/tactical/starship.toml" ~/.config/tactical/starship.toml
cp "$REPO_DIR/tactical/.config/tactical/zsh/.zshrc" ~/.config/tactical/zsh/.zshrc

# -------------------------------------------------------------
# 7. 安装h命令
# -------------------------------------------------------------
if [[ -f "$REPO_DIR/bin/h" ]]; then
    info "安装h命令 ..."
    mkdir -p ~/.local/bin
    cp "$REPO_DIR/bin/h" ~/.local/bin/h
    chmod +x ~/.local/bin/h
fi

# -------------------------------------------------------------
# 8. 安装中文帮助
# -------------------------------------------------------------
if [[ -d "$REPO_DIR/share/zhhelp" ]]; then
    info "安装中文帮助 ..."
    mkdir -p ~/.local/share/zhhelp
    cp "$REPO_DIR/share/zhhelp"/*.txt ~/.local/share/zhhelp/
fi
if [[ -f "$REPO_DIR/share/zhhelp-wrapper.sh" ]]; then
    cp "$REPO_DIR/share/zhhelp-wrapper.sh" ~/.local/share/zhhelp-wrapper.sh
fi

# -------------------------------------------------------------
# 9. 设置默认shell为zsh
# -------------------------------------------------------------
if [[ "$(getent passwd "$USER_NAME" | cut -d: -f7)" != "/usr/bin/zsh" ]]; then
    info "设置默认shell为zsh ..."
    sudo chsh -s /usr/bin/zsh "$USER_NAME"
fi

# -------------------------------------------------------------
# 10. 配置终端环境变量
# -------------------------------------------------------------
info "配置终端环境变量 ..."
mkdir -p ~/.config/environment.d
cat > ~/.config/environment.d/tty.conf << 'EOF'
# TTY独立配置 - 荧光绿色系
STARSHIP_CONFIG=$HOME/.config/tactical/starship.toml
ZDOTDIR=$HOME/.config/tactical/zsh
COLORTERM=truecolor
EOF

info "全部完成！"
info "请重新登录或执行以下命令生效："
info "  source ~/.config/tactical/zsh/.zshrc"
info "  tmux source-file ~/.tmux.conf"
