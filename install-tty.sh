#!/usr/bin/env bash
# =============================================================
# 无图形化界面系统配置脚本
# 仅安装TUI相关配置，荧光绿色系主题
# 用法: ./install-tty.sh [--update]
# =============================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_NAME="${SUDO_USER:-$USER}"

info() { printf '\033[1;32m[tty-install]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[tty-warning]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[tty-error]\033[0m %s\n' "$*" >&2; exit 1; }

# -------------------------------------------------------------
# 0. 自动更新功能
# -------------------------------------------------------------
if [[ "${1:-}" == "--update" ]]; then
    info "正在从GitHub拉取最新配置..."
    cd "$REPO_DIR"
    git pull origin main || die "拉取失败，请检查网络连接"
    info "配置已更新，请重新运行脚本"
    exit 0
fi

# -------------------------------------------------------------
# 0.1 镜像站配置（使用上海交大源 - 唯一可用）
# -------------------------------------------------------------
configure_mirrors() {
    info "配置镜像站（使用上海交大源）..."
    
    # 直接使用上海交大镜像（唯一可用）
    local mirror="https://mirrors.sjtug.sjtu.edu.cn"
    
    # 备份原始镜像配置
    if [[ -f /etc/pacman.d/mirrorlist ]]; then
        sudo cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
    fi
    
    # 清理旧的镜像配置并写入新的
    sudo tee /etc/pacman.d/mirrorlist > /dev/null << EOF
# 上海交大镜像（唯一可用）
Server = $mirror/archlinux/\$repo/os/\$arch
EOF
    
    # 清理archlinuxcn仓库镜像（如果存在）
    if grep -q "^\[archlinuxcn\]" /etc/pacman.conf 2>/dev/null; then
        # 备份pacman.conf
        sudo cp /etc/pacman.conf /etc/pacman.conf.bak
        
        # 替换archlinuxcn部分
        sudo sed -i '/\[archlinuxcn\]/,/^$/c\[archlinuxcn]\nServer = '"$mirror"'/archlinuxcn/\$arch' /etc/pacman.conf
    fi
    
    # 更新pacman密钥
    info "初始化pacman密钥..."
    sudo pacman-key --init 2>/dev/null || true
    sudo pacman-key --populate archlinux 2>/dev/null || true
    
    # 强制刷新包数据库
    info "刷新包数据库..."
    sudo pacman -Syy --noconfirm
    
    info "镜像站已配置为: $mirror"
}

# -------------------------------------------------------------
# 1. 配置镜像站
# -------------------------------------------------------------
configure_mirrors

# -------------------------------------------------------------
# 2. 安装TUI相关软件
# -------------------------------------------------------------
TTY_PKGS=(
    # 终端
    foot alacritty tmux zsh
    # Shell增强
    zsh-autocomplete zsh-autosuggestions zsh-syntax-highlighting
    # 文件管理
    yazi eza bat fzf fd ripgrep tree
    # 系统监控
    btop fastfetch
    # 提示符
    starship zoxide
    # 中文支持
    noto-fonts-cjk man-pages-zh_cn
    # 工具
    jq sqlite openssl
    # 开发
    git github-cli
    # AI工具
    nodejs npm python python3
)

info "安装TUI相关软件 ..."
sudo pacman -S --needed --noconfirm "${TTY_PKGS[@]}"

# -------------------------------------------------------------
# 3. 安装AUR工具
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
# 4. 移植foot配置
# -------------------------------------------------------------
info "移植foot配置 ..."
mkdir -p ~/.config/foot
cp "$REPO_DIR/foot/.config/foot/foot.ini" ~/.config/foot/foot.ini

# -------------------------------------------------------------
# 4.1 移植alacritty配置
# -------------------------------------------------------------
info "移植alacritty配置 ..."
mkdir -p ~/.config/alacritty
cp "$REPO_DIR/alacritty/.config/alacritty/alacritty.toml" ~/.config/alacritty/alacritty.toml

# -------------------------------------------------------------
# 5. 移植tmux配置
# -------------------------------------------------------------
info "移植tmux配置 ..."
cp "$REPO_DIR/tmux/.tmux.conf" ~/.tmux.conf

# -------------------------------------------------------------
# 6. 移植yazi配置
# -------------------------------------------------------------
info "移植yazi配置 ..."
mkdir -p ~/.config/yazi
cp "$REPO_DIR/yazi/.config/yazi/theme.toml" ~/.config/yazi/theme.toml

# -------------------------------------------------------------
# 6.1 移植btop配置
# -------------------------------------------------------------
info "移植btop配置 ..."
mkdir -p ~/.config/btop
cp "$REPO_DIR/btop/.config/btop/"* ~/.config/btop/ 2>/dev/null || true

# -------------------------------------------------------------
# 6.2 移植starship配置
# -------------------------------------------------------------
info "移植starship配置 ..."
cp "$REPO_DIR/starship/.config/starship.toml.custom" ~/.config/starship.toml.custom 2>/dev/null || true

# -------------------------------------------------------------
# 7. 移植tactical配置（独立绿色主题）
# -------------------------------------------------------------
info "移植tactical配置 ..."
mkdir -p ~/.config/tactical/zsh
cp "$REPO_DIR/tactical/.config/tactical/starship.toml" ~/.config/tactical/starship.toml
cp "$REPO_DIR/tactical/.config/tactical/zsh/.zshrc" ~/.config/tactical/zsh/.zshrc

# -------------------------------------------------------------
# 7.1 移植bash配置
# -------------------------------------------------------------
info "移植bash配置 ..."
cp "$REPO_DIR/bash/.bashrc" ~/.bashrc 2>/dev/null || true

# -------------------------------------------------------------
# 7.2 移植zsh配置
# -------------------------------------------------------------
info "移植zsh配置 ..."
cp "$REPO_DIR/zsh/.zshrc" ~/.zshrc 2>/dev/null || true

# -------------------------------------------------------------
# 8. 安装h命令
# -------------------------------------------------------------
if [[ -f "$REPO_DIR/bin/h" ]]; then
    info "安装h命令 ..."
    mkdir -p ~/.local/bin
    cp "$REPO_DIR/bin/h" ~/.local/bin/h
    chmod +x ~/.local/bin/h
fi

# -------------------------------------------------------------
# 9. 安装中文帮助
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
# 10. 安装fastfetch绿色版配置
# -------------------------------------------------------------
if [[ -f "$REPO_DIR/fastfetch/.config/fastfetch/config-green.jsonc" ]]; then
    info "安装fastfetch绿色版配置 ..."
    mkdir -p ~/.config/fastfetch
    cp "$REPO_DIR/fastfetch/.config/fastfetch/config-green.jsonc" ~/.config/fastfetch/config-green.jsonc
fi
if [[ -f "$REPO_DIR/fastfetch/.local/bin/fastfetch-switch.sh" ]]; then
    mkdir -p ~/.local/bin
    cp "$REPO_DIR/fastfetch/.local/bin/fastfetch-switch.sh" ~/.local/bin/fastfetch-switch.sh
    chmod +x ~/.local/bin/fastfetch-switch.sh
fi

# -------------------------------------------------------------
# 11. 安装hackingtools
# -------------------------------------------------------------
if [[ -d "$REPO_DIR/hackingtools" ]]; then
    info "安装hackingtools ..."
    mkdir -p ~/.local/share/hackingtools
    cp -r "$REPO_DIR/hackingtools"/* ~/.local/share/hackingtools/
    
    # 创建符号链接到bin目录
    mkdir -p ~/.local/bin
    for tool in ~/.local/share/hackingtools/bin/*; do
        if [[ -f "$tool" ]] || [[ -L "$tool" ]]; then
            ln -sf "$tool" ~/.local/bin/"$(basename "$tool")"
        fi
    done
fi

# -------------------------------------------------------------
# 12. 设置默认shell为zsh
# -------------------------------------------------------------
if [[ "$(getent passwd "$USER_NAME" | cut -d: -f7)" != "/usr/bin/zsh" ]]; then
    info "设置默认shell为zsh ..."
    sudo chsh -s /usr/bin/zsh "$USER_NAME"
fi

# -------------------------------------------------------------
# 13. 配置终端环境变量
# -------------------------------------------------------------
info "配置终端环境变量 ..."
mkdir -p ~/.config/environment.d
cat > ~/.config/environment.d/tty.conf << 'EOF'
# TTY独立配置 - 荧光绿色系
STARSHIP_CONFIG=$HOME/.config/tactical/starship.toml
ZDOTDIR=$HOME/.config/tactical/zsh
COLORTERM=truecolor
PATH=$HOME/.local/bin:$HOME/.local/share/hackingtools/bin:$PATH
EOF

# 添加到shell配置
for rc in ~/.bashrc ~/.zshrc; do
    if [[ -f "$rc" ]]; then
        # 检查是否已添加
        if ! grep -q "hackingtools" "$rc" 2>/dev/null; then
            echo "" >> "$rc"
            echo "# hackingtools" >> "$rc"
            echo 'export PATH="$HOME/.local/share/hackingtools/bin:$PATH"' >> "$rc"
        fi
    fi
done

info "全部完成！"
info "请重新登录或执行以下命令生效："
info "  source ~/.config/tactical/zsh/.zshrc"
info "  tmux source-file ~/.tmux.conf"
info "  export PATH=\"\$HOME/.local/share/hackingtools/bin:\$PATH\""
