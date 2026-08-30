#!/usr/bin/env bash
# =============================================================
# TUI System Configuration Script
# 仅安装TUI相关配置，荧光绿色系主题
# 用法: ./install-tty.sh [--update]
# =============================================================
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_NAME="${SUDO_USER:-$USER}"

# -------------------------------------------------------------
# 语言控制（开始英文，装完字体后切中文）
# -------------------------------------------------------------
LANG_EN=1

# 英文信息函数
info_en() { printf '\033[1;32m[tty-install]\033[0m %s\n' "$*"; }
warn_en() { printf '\033[1;33m[tty-warning]\033[0m %s\n' "$*"; }
die_en()  { printf '\033[1;31m[tty-error]\033[0m %s\n' "$*" >&2; exit 1; }

# 中文信息函数
info_cn() { printf '\033[1;32m[tty安装]\033[0m %s\n' "$*"; }
warn_cn() { printf '\033[1;33m[tty警告]\033[0m %s\n' "$*"; }
die_cn()  { printf '\033[1;31m[tty错误]\033[0m %s\n' "$*" >&2; exit 1; }

# 统一接口
info() { [[ "$LANG_EN" == "1" ]] && info_en "$@" || info_cn "$@"; }
warn() { [[ "$LANG_EN" == "1" ]] && warn_en "$@" || warn_cn "$@"; }
die()  { [[ "$LANG_EN" == "1" ]] && die_en "$@" || die_cn "$@"; }

# -------------------------------------------------------------
# 0. Auto Update
# -------------------------------------------------------------
if [[ "${1:-}" == "--update" ]]; then
    info_en "Pulling latest config from GitHub..."
    cd "$REPO_DIR"
    git pull origin main || die_en "Pull failed, check network"
    info_en "Config updated, please re-run script"
    exit 0
fi

# -------------------------------------------------------------
# 0.1 Pacman Auto Repair
# -------------------------------------------------------------
repair_pacman() {
    info_en "Checking and repairing pacman..."
    
    # 1. Check and repair keyring
    if [[ -d /etc/pacman.d/gnupg ]]; then
        # Test if keyring is valid
        if ! sudo pacman-key --list-keys &>/dev/null; then
            warn_en "Keyring corrupted, reinitializing..."
            sudo rm -rf /etc/pacman.d/gnupg
            sudo pacman-key --init
        fi
    else
        info_en "Initializing pacman keyring..."
        sudo pacman-key --init
    fi
    
    # 2. Populate archlinux keyring
    sudo pacman-key --populate archlinux 2>/dev/null || true
    
    # 3. Import archlinuxcn key if repo exists
    if grep -q "^\[archlinuxcn\]" /etc/pacman.conf 2>/dev/null; then
        info_en "Importing archlinuxcn key..."
        sudo pacman-key --recv-keys 74F4207F0D0BC945E4AB5F78FE748387E4596636 2>/dev/null || true
        sudo pacman-key --lsign-key 74F4207F0D0BC945E4AB5F78FE748387E4596636 2>/dev/null || true
    fi
    
    # 4. Clean and rebuild package database
    info_en "Rebuilding package database..."
    sudo rm -f /var/lib/pacman/sync/*.db 2>/dev/null || true
    sudo pacman -Syy --noconfirm
    
    # 5. Verify SigLevel in pacman.conf
    if ! grep -q "^SigLevel.*=.*Required DatabaseOptional" /etc/pacman.conf 2>/dev/null; then
        warn_en "Fixing SigLevel in pacman.conf..."
        sudo sed -i 's/^#SigLevel\s*=/SigLevel =/' /etc/pacman.conf
        sudo sed -i 's/^SigLevel\s*=\s*$/SigLevel = Required DatabaseOptional/' /etc/pacman.conf
    fi
    
    info_en "Pacman repair completed"
}

# -------------------------------------------------------------
# 0.2 Mirror Configuration (SJTU - only working mirror)
# -------------------------------------------------------------
configure_mirrors() {
    info_en "Configuring mirror (SJTU)..."
    
    local mirror="https://mirrors.sjtug.sjtu.edu.cn"
    
    # Backup original mirrorlist
    if [[ -f /etc/pacman.d/mirrorlist ]]; then
        sudo cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
    fi
    
    # Write new mirrorlist
    sudo tee /etc/pacman.d/mirrorlist > /dev/null << EOF
# SJTU Mirror (only working mirror)
Server = $mirror/archlinux/\$repo/os/\$arch
EOF
    
    # Fix archlinuxcn repo if exists
    if grep -q "^\[archlinuxcn\]" /etc/pacman.conf 2>/dev/null; then
        sudo cp /etc/pacman.conf /etc/pacman.conf.bak
        sudo sed -i '/\[archlinuxcn\]/,/^$/c\[archlinuxcn]\nServer = '"$mirror"'/archlinuxcn/\$arch' /etc/pacman.conf
    fi
    
    # Init pacman keys
    info_en "Initializing pacman keys..."
    sudo pacman-key --init 2>/dev/null || true
    sudo pacman-key --populate archlinux 2>/dev/null || true
    
    # Force refresh package database
    info_en "Refreshing package database..."
    sudo pacman -Syy --noconfirm
    
    info_en "Mirror configured: $mirror"
}

# -------------------------------------------------------------
# 1. Repair Pacman and Configure Mirror
# -------------------------------------------------------------
repair_pacman
configure_mirrors

# -------------------------------------------------------------
# 2. Install Chinese Fonts (first priority)
# -------------------------------------------------------------
info_en "Installing Chinese fonts..."
sudo pacman -S --needed --noconfirm noto-fonts-cjk man-pages-zh_cn

# Switch to Chinese after fonts installed
LANG_EN=0
info "中文字体安装完成，切换到中文显示"

# -------------------------------------------------------------
# 3. Install TUI Software
# -------------------------------------------------------------
TTY_PKGS=(
    # Terminal
    foot alacritty tmux zsh
    # Shell Enhancement
    zsh-autocomplete zsh-autosuggestions zsh-syntax-highlighting
    # File Manager
    yazi eza bat fzf fd ripgrep tree
    # System Monitor
    btop fastfetch
    # Prompt
    starship zoxide
    # Tools
    jq sqlite openssl
    # Development
    git github-cli
    # AI Tools
    nodejs npm python python3
    # AUR Helper (from archlinuxcn)
    yay
)

info "安装TUI相关软件 ..."
sudo pacman -S --needed --noconfirm "${TTY_PKGS[@]}" || {
    warn "部分软件安装失败，继续执行..."
}

# -------------------------------------------------------------
# 4. AUR Helper (fallback if yay not installed)
# -------------------------------------------------------------
if ! command -v yay &>/dev/null; then
    warn "yay未安装，尝试从AUR构建..."
    
    # Ensure base-devel is installed
    sudo pacman -S --needed --noconfirm base-devel git
    
    # Build yay from AUR
    cd /tmp
    rm -rf yay-build
    if git clone https://aur.archlinux.org/yay.git yay-build; then
        cd yay-build
        if makepkg -si --noconfirm; then
            info "yay构建成功"
        else
            warn "yay构建失败，部分AUR功能不可用"
        fi
    else
        warn "无法克隆yay仓库，部分AUR功能不可用"
    fi
fi

# -------------------------------------------------------------
# 5. Deploy foot Config
# -------------------------------------------------------------
info "移植foot配置 ..."
mkdir -p ~/.config/foot
cp "$REPO_DIR/foot/.config/foot/foot.ini" ~/.config/foot/foot.ini

# -------------------------------------------------------------
# 5.1 Deploy alacritty Config
# -------------------------------------------------------------
info "移植alacritty配置 ..."
mkdir -p ~/.config/alacritty
cp "$REPO_DIR/alacritty/.config/alacritty/alacritty.toml" ~/.config/alacritty/alacritty.toml

# -------------------------------------------------------------
# 6. Deploy tmux Config
# -------------------------------------------------------------
info "移植tmux配置 ..."
cp "$REPO_DIR/tmux/.tmux.conf" ~/.tmux.conf

# -------------------------------------------------------------
# 7. Deploy yazi Config
# -------------------------------------------------------------
info "移植yazi配置 ..."
mkdir -p ~/.config/yazi
cp "$REPO_DIR/yazi/.config/yazi/theme.toml" ~/.config/yazi/theme.toml

# -------------------------------------------------------------
# 7.1 Deploy btop Config
# -------------------------------------------------------------
info "移植btop配置 ..."
mkdir -p ~/.config/btop
cp "$REPO_DIR/btop/.config/btop/"* ~/.config/btop/ 2>/dev/null || true

# -------------------------------------------------------------
# 7.2 Deploy starship Config
# -------------------------------------------------------------
info "移植starship配置 ..."
cp "$REPO_DIR/starship/.config/starship.toml.custom" ~/.config/starship.toml.custom 2>/dev/null || true

# -------------------------------------------------------------
# 8. Deploy tactical Config (independent green theme)
# -------------------------------------------------------------
info "移植tactical配置 ..."
mkdir -p ~/.config/tactical/zsh
cp "$REPO_DIR/tactical/.config/tactical/starship.toml" ~/.config/tactical/starship.toml
cp "$REPO_DIR/tactical/.config/tactical/zsh/.zshrc" ~/.config/tactical/zsh/.zshrc

# -------------------------------------------------------------
# 8.1 Deploy bash Config
# -------------------------------------------------------------
info "移植bash配置 ..."
cp "$REPO_DIR/bash/.bashrc" ~/.bashrc 2>/dev/null || true

# -------------------------------------------------------------
# 8.2 Deploy zsh Config
# -------------------------------------------------------------
info "移植zsh配置 ..."
cp "$REPO_DIR/zsh/.zshrc" ~/.zshrc 2>/dev/null || true

# -------------------------------------------------------------
# 9. Install all bin scripts
# -------------------------------------------------------------
if [[ -d "$REPO_DIR/bin" ]]; then
    info "安装bin目录脚本 ..."
    mkdir -p ~/.local/bin
    for script in "$REPO_DIR/bin/"*; do
        if [[ -f "$script" ]] && [[ "$(basename "$script")" != ".local" ]]; then
            cp "$script" ~/.local/bin/
            chmod +x ~/.local/bin/"$(basename "$script")"
        fi
    done
fi

# Install root-level scripts (ff, etc)
for script in ff; do
    if [[ -f "$REPO_DIR/$script" ]]; then
        info "安装${script}脚本 ..."
        mkdir -p ~/.local/bin
        cp "$REPO_DIR/$script" ~/.local/bin/
        chmod +x ~/.local/bin/"$script"
    fi
done

# -------------------------------------------------------------
# 10. Install Chinese Help
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
# 11. Install fastfetch green config
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
# 12. Install hackingtools
# -------------------------------------------------------------
if [[ -d "$REPO_DIR/hackingtools" ]]; then
    info "安装hackingtools ..."
    mkdir -p ~/.local/share/hackingtools
    cp -r "$REPO_DIR/hackingtools"/* ~/.local/share/hackingtools/
    
    # Create symlinks to bin directory
    mkdir -p ~/.local/bin
    for tool in ~/.local/share/hackingtools/bin/*; do
        if [[ -f "$tool" ]] || [[ -L "$tool" ]]; then
            ln -sf "$tool" ~/.local/bin/"$(basename "$tool")"
        fi
    done
fi

# -------------------------------------------------------------
# 13. Set default shell to zsh
# -------------------------------------------------------------
if [[ "$(getent passwd "$USER_NAME" | cut -d: -f7)" != "/usr/bin/zsh" ]]; then
    info "设置默认shell为zsh ..."
    sudo chsh -s /usr/bin/zsh "$USER_NAME"
fi

# -------------------------------------------------------------
# 14. Configure Environment Variables
# -------------------------------------------------------------
info "配置终端环境变量 ..."
mkdir -p ~/.config/environment.d
cat > ~/.config/environment.d/tty.conf << 'EOF'
# TTY独立配置 - 荧光绿色系
STARSHIP_CONFIG=$HOME/.config/tactical/starship.toml
ZDOTDIR=$HOME/.config/tactical/zsh
COLORTERM=truecolor
EOF

# Add to shell config
for rc in ~/.bashrc ~/.zshrc; do
    if [[ -f "$rc" ]]; then
        # Add STARSHIP_CONFIG if not present
        if ! grep -q "STARSHIP_CONFIG" "$rc" 2>/dev/null; then
            echo "" >> "$rc"
            echo "# TTY Environment" >> "$rc"
            echo 'export STARSHIP_CONFIG="$HOME/.config/tactical/starship.toml"' >> "$rc"
            echo 'export ZDOTDIR="$HOME/.config/tactical/zsh"' >> "$rc"
        fi
        # Add hackingtools to PATH if not present
        if ! grep -q "hackingtools" "$rc" 2>/dev/null; then
            echo 'export PATH="$HOME/.local/bin:$HOME/.local/share/hackingtools/bin:$PATH"' >> "$rc"
        fi
    fi
done

info "全部完成！"
info "请重新登录或执行以下命令生效："
info "  source ~/.config/tactical/zsh/.zshrc"
info "  tmux source-file ~/.tmux.conf"
