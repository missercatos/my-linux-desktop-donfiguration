#!/usr/bin/env bash
# =============================================================
# Desktop System Configuration Script
# 一键安装脚本：安装所需软件 + 通过 GNU Stow 移植全部配置
# 用法: ./install.sh [--update]
# 依赖: 已登录 sudo（脚本会请求一次密码）
# =============================================================
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_NAME="${SUDO_USER:-$USER}"

# -------------------------------------------------------------
# Language Control (English first, switch to Chinese after fonts)
# -------------------------------------------------------------
LANG_EN=1

# English info functions
info_en() { printf '\033[1;32m[install]\033[0m %s\n' "$*"; }
warn_en() { printf '\033[1;33m[warning]\033[0m %s\n' "$*"; }
die_en()  { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

# Chinese info functions
info_cn() { printf '\033[1;32m[安装]\033[0m %s\n' "$*"; }
warn_cn() { printf '\033[1;33m[警告]\033[0m %s\n' "$*"; }
die_cn()  { printf '\033[1;31m[错误]\033[0m %s\n' "$*" >&2; exit 1; }

# Unified interface
info() { [[ "$LANG_EN" == "1" ]] && info_en "$@" || info_cn "$@"; }
warn() { [[ "$LANG_EN" == "1" ]] && warn_en "$@" || warn_cn "$@"; }
die()  { [[ "$LANG_EN" == "1" ]] && die_en "$@" || die_cn "$@"; }

command -v sudo >/dev/null || die_en "sudo not found"

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
# 3. Install Official/archlinuxcn Packages
# -------------------------------------------------------------
OFFICIAL_PKGS=(
    # Desktop Stack
    niri kitty fish neovim stow dms-shell dms-shell-niri
    noctalia-qs base-devel
    starship fastfetch cava btop yazi fuzzel foot alacritty
    eza bat zoxide tmux zellij fzf ripgrep fd
    # Tools
    git gnupg openssh curl wget rsync gzip xz zip unzip 7zip
    imagemagick ffmpeg jq sqlite openssl gdb tldr
    coreutils findutils sed grep procps-ng util-linux iproute2
    nodejs yt-dlp docker docker-compose mpv wl-clipboard wireplumber networkmanager
    # Screen Recording
    wf-recorder slurp libnotify
    # Kitty Terminal
    kitty-shell-integration kitty-terminfo
    # Git Extensions
    git-lfs
    # CTF/Security Tools
    binwalk gdb radare2 rizin ghidra jadx
    wireshark-cli socat smbclient strace ltrace
    # Python CTF Libraries
    python-pwntools python-capstone python-unicorn python-pycryptodomex ropgadget
    python-pyelftools python-pyserial
    # zsh Alternative
    zsh zsh-syntax-highlighting zsh-autosuggestions zsh-autocomplete zsh-completions
    # Chinese man pages
    man-pages-zh_cn
    # Display Manager (Wayland + X11)
    sddm sddm-kcm ly
    # Input Method
    fcitx5 fcitx5-chinese-addons fcitx5-configtool fcitx5-gtk fcitx5-qt
    # Virtualization
    qemu-full virt-manager libvirt dnsmasq edk2-ovmf
    # Media Player (Wayland + X11)
    mpv mpv-vapoursynth
    # Audio (PipeWire + PulseAudio compat)
    pipewire pipewire-pulse pipewire-alsa pipewire-jack wireplumber
    # Plasma (Wayland + X11)
    plasma-desktop plasma-workspace plasma-wayland-session
    sddm-kcm systemsettings
    # Browser
    firefox firefox-i18n-zh-cn
)
info "安装官方仓库软件 ..."
sudo pacman -S --needed --noconfirm "${OFFICIAL_PKGS[@]}" || {
    warn "部分软件安装失败，继续执行..."
}

# -------------------------------------------------------------
# 3.1 Install yay from archlinuxcn
# -------------------------------------------------------------
if ! command -v yay &>/dev/null; then
    info "安装 yay (AUR helper) ..."
    # Ensure archlinuxcn repo exists
    if ! grep -q "^\[archlinuxcn\]" /etc/pacman.conf 2>/dev/null; then
        info "添加 archlinuxcn 仓库 ..."
        sudo tee -a /etc/pacman.conf > /dev/null << 'CNF'

[archlinuxcn]
Server = https://mirrors.sjtug.sjtu.edu.cn/archlinuxcn/$arch
CNF
        sudo pacman -Syy --noconfirm 2>/dev/null || true
    fi
    # Import archlinuxcn key
    sudo pacman-key --recv-keys 74F4207F0D0BC945E4AB5F78FE748387E4596636 2>/dev/null || true
    sudo pacman-key --lsign-key 74F4207F0D0BC945E4AB5F78FE748387E4596636 2>/dev/null || true
    sudo pacman -Syy --noconfirm 2>/dev/null || true
    sudo pacman -S --needed --noconfirm yay || {
        warn "yay 安装失败，跳过 AUR 软件安装"
    }
fi

if command -v yay &>/dev/null; then
    info "yay已安装: $(yay --version)"
else
    warn "yay未安装，AUR功能将不可用"
fi

# -------------------------------------------------------------
# 4.1 Install AUR Packages
# -------------------------------------------------------------
AUR_PKGS=(
    # Desktop
    niri-sidebar-git
    shorin-dms-niri-git
    shorin-contrib-git
    shorin-screenrec-menu-git
    github-desktop-bin
    wayscriber-bin
    obs-cmd-bin
    # VPN/Proxy
    flclash-bin
    mihomo
    # Chinese Apps
    wechat-universal-bwrap
    dingtalk-bin
    linuxqq
    # Browser
    google-chrome-stable
    # Wallpaper
    swww
)

if command -v yay &>/dev/null; then
    info "通过 yay 安装 AUR 软件 ..."
    yay -S --needed --noconfirm "${AUR_PKGS[@]}" || {
        warn "部分AUR软件安装失败，继续执行..."
    }
else
    warn "yay不可用，跳过AUR软件安装"
fi

# -------------------------------------------------------------
# 4.2 Fix qs and qt6-base version mismatch
# -------------------------------------------------------------
if command -v qs >/dev/null && qs --version 2>&1 | grep -q "symbol lookup error"; then
    warn "检测到 qs 与 qt6-base 版本不匹配，从 AUR 重建 quickshell-git..."
    sudo pacman -Rdd --noconfirm noctalia-qs 2>/dev/null || true
    if command -v yay &>/dev/null && yay -S --noconfirm --aur quickshell-git; then
        info "quickshell-git 重建完成"
    else
        warn "自动重建失败，请手动执行：yay -S --aur quickshell-git"
    fi
fi

# -------------------------------------------------------------
# 5. Configure Display Manager
# -------------------------------------------------------------
info "配置显示管理器..."

# Enable SDDM (default)
sudo systemctl enable sddm.service 2>/dev/null || true

# Install ly but disable (as alternative)
sudo systemctl disable ly.service 2>/dev/null || true

# -------------------------------------------------------------
# 6. Stow Deploy Configs
# -------------------------------------------------------------
cd "$REPO_DIR"
info "通过 GNU Stow 移植配置到 \$HOME ..."
for pkg in */; do
    pkg="${pkg%/}"
    case "$pkg" in
        .git|sddm|dms-sysmon|transparent-blur|applications|icons) continue ;;
    esac
    if [[ -d "$pkg" ]]; then
        stow --restow "$pkg" 2>/dev/null || {
            warn "Stow移植 $pkg 失败，继续执行..."
        }
    fi
done

# Special: /etc configs
if [[ -f sddm/etc/sddm.conf ]]; then
    info "移植 sddm 配置到 /etc ..."
    sudo stow --target=/ --restow sddm 2>/dev/null || true
fi

# Fix ~/.xprofile ownership if needed
if [[ -e "$HOME/.xprofile" && "$(stat -c %U "$HOME/.xprofile")" = "root" ]]; then
    info "修正 ~/.xprofile 归属 ..."
    sudo chown "$USER_NAME":"$USER_NAME" "$HOME/.xprofile"
fi

# -------------------------------------------------------------
# 7. Configure Desktop Environments
# -------------------------------------------------------------
info "配置桌面环境..."

# Ensure niri config directory exists
mkdir -p ~/.config/niri
if [[ -d "$REPO_DIR/niri/.config/niri" ]]; then
    cp -r "$REPO_DIR/niri/.config/niri/"* ~/.config/niri/ 2>/dev/null || true
fi

# Ensure hyprland config directory exists
mkdir -p ~/.config/hypr
if [[ -d "$REPO_DIR/hyprland/.config/hypr" ]]; then
    cp -r "$REPO_DIR/hyprland/.config/hypr/"* ~/.config/hypr/ 2>/dev/null || true
fi

# Ensure plasma config directory exists
mkdir -p ~/.config
if [[ -d "$REPO_DIR/plasma/.config" ]]; then
    cp -r "$REPO_DIR/plasma/.config/"* ~/.config/ 2>/dev/null || true
fi

# -------------------------------------------------------------
# 8. Set default shell to fish
# -------------------------------------------------------------
if [[ "$(getent passwd "$USER_NAME" | cut -d: -f7)" != "/usr/bin/fish" ]]; then
    info "设置默认 shell 为 fish ..."
    sudo chsh -s /usr/bin/fish "$USER_NAME"
fi

# -------------------------------------------------------------
# 9. Finalize
# -------------------------------------------------------------
if command -v niri >/dev/null && pgrep -x niri >/dev/null; then
    info "niri 正在运行，重载配置 ..."
    niri msg action reload-config || warn "niri 重载失败，请手动执行 niri msg action reload-config"
fi

# -------------------------------------------------------------
# 10. Install all bin scripts
# -------------------------------------------------------------
if [[ -d "$REPO_DIR/config/bin" ]]; then
    info "安装bin目录脚本和工具 ..."
    mkdir -p "$HOME/.local/bin"
    for script in "$REPO_DIR/config/bin/"*; do
        if [[ -f "$script" ]]; then
            cp "$script" "$HOME/.local/bin/"
            chmod +x "$HOME/.local/bin/$(basename "$script")"
        fi
    done
    info "已安装 $(ls "$REPO_DIR/config/bin/" | wc -l) 个脚本/工具到 ~/.local/bin/"
fi

# Install system-level scripts to /usr/local/bin/
if [[ -f "$REPO_DIR/config/bin/steama" ]]; then
    info "安装 steama 到 /usr/local/bin/ ..."
    sudo cp "$REPO_DIR/config/bin/steama" /usr/local/bin/steama
    sudo chmod +x /usr/local/bin/steama
fi

# Install root-level scripts (ff, etc)
for script in ff; do
    if [[ -f "$REPO_DIR/$script" ]]; then
        info "安装${script}脚本 ..."
        mkdir -p "$HOME/.local/bin"
        cp "$REPO_DIR/$script" "$HOME/.local/bin/"
        chmod +x "$HOME/.local/bin/$script"
    fi
done

# -------------------------------------------------------------
# 11. Install Chinese Help
# -------------------------------------------------------------
if [[ -f "$REPO_DIR/config/share/zhhelp-wrapper.sh" ]]; then
    info "安装中文帮助包装脚本 ..."
    mkdir -p "$HOME/.local/share"
    cp "$REPO_DIR/config/share/zhhelp-wrapper.sh" "$HOME/.local/share/zhhelp-wrapper.sh"
fi

# -------------------------------------------------------------
# 12. Install fastfetch green config
# -------------------------------------------------------------
if [[ -f "$REPO_DIR/config/fastfetch-switch.sh" ]]; then
    mkdir -p "$HOME/.local/bin"
    cp "$REPO_DIR/config/fastfetch-switch.sh" "$HOME/.local/bin/fastfetch-switch.sh"
    chmod +x "$HOME/.local/bin/fastfetch-switch.sh"
fi

# -------------------------------------------------------------
# 14. Install hackingtools
# -------------------------------------------------------------
if [[ -d "$REPO_DIR/hackingtools" ]]; then
    info "安装hackingtools ..."
    mkdir -p "$HOME/.local/share/hackingtools"
    cp -r "$REPO_DIR/hackingtools"/* "$HOME/.local/share/hackingtools/"
    
    # Create symlinks to bin directory
    mkdir -p "$HOME/.local/bin"
    for tool in "$HOME/.local/share/hackingtools/bin/"*; do
        if [[ -f "$tool" ]] || [[ -L "$tool" ]]; then
            ln -sf "$tool" "$HOME/.local/bin/$(basename "$tool")"
        fi
    done
fi

# -------------------------------------------------------------
# 15. Configure Environment Variables
# -------------------------------------------------------------
info "配置环境变量 ..."
mkdir -p ~/.config/environment.d

# Copy environment.d config files from project
if [[ -d "$REPO_DIR/config/environment.d" ]]; then
    cp "$REPO_DIR/config/environment.d/"* ~/.config/environment.d/ 2>/dev/null || true
    info "已复制环境变量配置文件"
fi

# Add to shell config
for rc in ~/.bashrc ~/.zshrc ~/.config/fish/config.fish; do
    if [[ -f "$rc" ]]; then
        # Add STARSHIP_CONFIG if not present (for TTY compatibility)
        if ! grep -q "STARSHIP_CONFIG" "$rc" 2>/dev/null; then
            if [[ "$rc" == *"fish"* ]]; then
                echo "" >> "$rc"
                echo "# TTY Environment" >> "$rc"
                echo 'set -gx STARSHIP_CONFIG "$HOME/.config/tactical/starship.toml"' >> "$rc"
                echo 'set -gx ZDOTDIR "$HOME/.config/tactical/zsh"' >> "$rc"
            else
                echo "" >> "$rc"
                echo "# TTY Environment" >> "$rc"
                echo 'export STARSHIP_CONFIG="$HOME/.config/tactical/starship.toml"' >> "$rc"
                echo 'export ZDOTDIR="$HOME/.config/tactical/zsh"' >> "$rc"
            fi
        fi
        # Add hackingtools and local bin to PATH if not present
        if ! grep -q "hackingtools" "$rc" 2>/dev/null; then
            if [[ "$rc" == *"fish"* ]]; then
                echo 'set -gx PATH $HOME/.local/bin $HOME/.local/share/hackingtools/bin $PATH' >> "$rc"
            else
                echo 'export PATH="$HOME/.local/bin:$HOME/.local/share/hackingtools/bin:$PATH"' >> "$rc"
            fi
        fi
        # Add fastfetch alias if not present (bash/zsh only)
        if [[ "$rc" != *"fish"* ]] && ! grep -q "fastfetch-switch.sh" "$rc" 2>/dev/null; then
            echo "" >> "$rc"
            echo "# fastfetch自动检测TTY配置" >> "$rc"
            echo 'if [[ -f ~/.local/bin/fastfetch-switch.sh ]]; then' >> "$rc"
            echo "    alias fastfetch='~/.local/bin/fastfetch-switch.sh auto'" >> "$rc"
            echo 'fi' >> "$rc"
        fi
    fi
done

# -------------------------------------------------------------
# 16. Configure fcitx5 Input Method
# -------------------------------------------------------------
info "配置 fcitx5 输入法 ..."

# Install fcitx5 packages if not present
sudo pacman -S --needed --noconfirm fcitx5 fcitx5-chinese-addons fcitx5-configtool fcitx5-gtk fcitx5-qt 2>/dev/null || true

# Configure environment variables for fcitx5
mkdir -p ~/.config/environment.d
cat > ~/.config/environment.d/input-method.conf << 'EOF'
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
SDL_IM_MODULE=fcitx
GLFW_IM_MODULE=ibus
EOF

# Configure fcitx5 shortcuts
mkdir -p ~/.config/fcitx5/conf
cat > ~/.config/fcitx5/config << 'EOF'
[Hotkey]
# Toggle input method
TriggerKeys=Control+space
EnumerateWithTriggerKeys=True
EnumerateForwardKeys=
EnumerateBackwardKeys=
EnumerateSkipFirst=False
ModifierOnlyKeyTimeout=250

[Hotkey/TriggerKeys]
0=Control+space
1=Zenkaku_Hankaku
2=Hangul

[Hotkey/ActivateKeys]
0=Hangul_Hanja

[Hotkey/DeactivateKeys]
0=Hangul_Hanja

[Hotkey]
# Forward
0=Control+space
EOF

# Configure fcitx5 classicui theme
cat > ~/.config/fcitx5/conf/classicui.conf << 'EOF'
# Vertical candidate list
Vertical Candidate List=True
# Use mouse wheel to page
WheelForPaging=True
# Font
Font="Sans Serif 11"
# Menu font
MenuFont="Sans Serif 10"
# Tray font
TrayFont="Sans Serif 10"
# Tray outline color
TrayOutlineColor=#000000
# Tray text color
TrayTextColor=#ffffff
# Prefer text icon
PreferTextIcon=False
# Show layout name in icon
ShowLayoutNameInIcon=True
# Use input method language to display text
UseInputMethodLanguageToDisplayText=True
EOF

info "fcitx5 配置完成，需要重启生效"

# -------------------------------------------------------------
# 17. Configure QEMU/KVM/libvirt
# -------------------------------------------------------------
info "配置 QEMU/KVM 虚拟化环境 ..."

# Install virtualization packages
sudo pacman -S --needed --noconfirm qemu-full virt-manager libvirt dnsmasq edk2-ovmf 2>/dev/null || true

# Enable libvirt service
sudo systemctl enable --now libvirtd 2>/dev/null || true

# Add user to libvirt group
sudo usermod -aG libvirt "$USER" 2>/dev/null || true

# Configure libvirt to use session connection
mkdir -p ~/.config/libvirt
cat > ~/.config/libvirt/libvirt.conf << 'EOF'
# Use session connection by default
uri_default = "qemu:///session"
EOF

info "QEMU/KVM 配置完成，需要重新登录使 libvirt 组生效"

# -------------------------------------------------------------
# 18. Configure VPN/Proxy Tools
# -------------------------------------------------------------
info "配置 VPN/代理工具 ..."

# Create clash/mihomo config directory
mkdir -p ~/.config/clash
mkdir -p ~/.config/mihomo

# Create mihomo basic config
cat > ~/.config/mihomo/config.yaml << 'EOF'
mixed-port: 7890
allow-lan: false
mode: rule
log-level: info
external-controller: 127.0.0.1:9090
EOF

# Install steamcommunity302
if [[ ! -d "/opt/steamcommunity302" ]]; then
    info "安装 steamcommunity302 ..."
    # Download and install steamcommunity302
    # Note: This is a placeholder - actual download URL may vary
    mkdir -p /tmp/steamcommunity302
    cd /tmp/steamcommunity302
    # User should download manually or use AUR if available
    info "steamcommunity302 需要手动安装: https://steamcommunity.302/"
    cd -
fi

# Install Watt Toolkit (瓦特工具箱)
if ! command -v watt &>/dev/null && ! command -v steampp &>/dev/null; then
    info "Watt Toolkit 需要手动安装: https://steampp.net/"
fi

info "VPN/代理工具配置完成"

# -------------------------------------------------------------
# 19. Configure DMS (DankMaterialShell)
# -------------------------------------------------------------
info "配置 DMS 桌面环境 ..."

# DMS is already installed via dms-shell packages
# Create config directory if not exists
mkdir -p ~/.config/DankMaterialShell

info "DMS 配置目录: ~/.config/DankMaterialShell/"

# -------------------------------------------------------------
# 20. Configure Wallpapers
# -------------------------------------------------------------
info "配置壁纸 ..."

# Copy wallpapers to user directory
mkdir -p ~/Pictures/Wallpapers
if [[ -d "$REPO_DIR/wallpapers" ]]; then
    cp -r "$REPO_DIR/wallpapers"/* ~/Pictures/Wallpapers/ 2>/dev/null || true
    info "已复制壁纸到 ~/Pictures/Wallpapers/"
fi

# Set first wallpaper as default (if swww is installed)
if command -v swww &>/dev/null; then
    FIRST_WALLPAPER=$(ls ~/Pictures/Wallpapers/*.jpg ~/Pictures/Wallpapers/*.png ~/Pictures/Wallpapers/*.jpeg 2>/dev/null | head -1)
    if [[ -n "$FIRST_WALLPAPER" ]]; then
        swww img "$FIRST_WALLPAPER" 2>/dev/null || true
        info "已设置默认壁纸: $(basename "$FIRST_WALLPAPER")"
    fi
fi

info ""
info "=========================================="
info "安装完成！"
info "=========================================="
info ""
info "默认 shell: fish"
info "输入法: fcitx5 (Ctrl+Space 切换)"
info "虚拟化: QEMU/KVM (需要重新登录使 libvirt 组生效)"
info "浏览器: Firefox (默认) + Google Chrome"
info "中国应用: 微信、钉钉、QQ"
info ""
info "快捷键参考:"
info "  Mod+G    - 屏幕画图 (wayscriber)"
info "  Mod+F3   - OBS 录屏"
info "  Mod+Ctrl+R - 快速录屏"
info "  Mod+F1   - 切换输入法"
info ""
info "更新方法: ./install.sh --update"
