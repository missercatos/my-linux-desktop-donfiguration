#!/usr/bin/env bash
# =============================================================
# 一键安装脚本：安装所需软件 + 通过 GNU Stow 移植全部配置
# 用法: ./install.sh [--update]
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
# 0.1 镜像站配置（自动检测地理位置）
# -------------------------------------------------------------
configure_mirrors() {
    info "配置镜像站..."
    
    # 获取IP并检测地理位置
    local ip=$(curl -s --connect-timeout 5 https://api.ipify.org 2>/dev/null || echo "")
    local mirror=""
    
    if [[ -n "$ip" ]]; then
        # 根据IP前缀判断区域（简化版）
        local prefix=$(echo "$ip" | cut -d'.' -f1)
        if [[ "$prefix" == "114" ]] || [[ "$prefix" == "180" ]] || [[ "$prefix" == "202" ]]; then
            # 中国IP段，使用中科大镜像
            mirror="https://mirrors.ustc.edu.cn"
        else
            # 默认使用上海交大镜像
            mirror="https://mirrors.sjtug.sjtu.edu.cn"
        fi
    else
        # 无法获取IP，默认使用中科大
        mirror="https://mirrors.ustc.edu.cn"
    fi
    
    # 备份原始镜像配置
    if [[ -f /etc/pacman.d/mirrorlist ]]; then
        sudo cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
    fi
    
    # 写入新镜像配置
    sudo tee /etc/pacman.d/mirrorlist > /dev/null << EOF
# 自动配置的镜像站
Server = $mirror/archlinux/\$arch
Server = $mirror/archlinux/\$arch/os
EOF
    
    info "镜像站已配置为: $mirror"
}

# -------------------------------------------------------------
# 1. 配置镜像站
# -------------------------------------------------------------
configure_mirrors

# -------------------------------------------------------------
# 2. 安装官方/archlinuxcn 仓库软件
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
    nodejs yt-dlp docker docker-compose mpv wl-clipboard wireplumber networkmanager
    # Kitty终端
    kitty-shell-integration kitty-terminfo
    # Git扩展
    git-lfs
    # CTF/安全工具
    binwalk gdb radare2 rizin ghidra jadx
    wireshark-cli socat smbclient strace ltrace
    # Python CTF 库
    python-pwntools python-capstone python-unicorn python-pycryptodomex ropgadget
    python-pyelftools python-pyserial
    # zsh 备选
    zsh zsh-syntax-highlighting zsh-autosuggestions zsh-autocomplete zsh-completions
    # 中文 man 手册
    man-pages-zh_cn
    # 显示管理器
    sddm ly
)
info "安装官方/archlinuxcn 仓库软件 ..."
sudo pacman -S --needed --noconfirm "${OFFICIAL_PKGS[@]}"

# -------------------------------------------------------------
# 3. AUR 软件（dms 相关）
# -------------------------------------------------------------
AUR_PKGS=(
    niri-sidebar-git
    shorin-dms-niri-git
    shorin-contrib-git
    shorin-screenrec-menu-git
    github-desktop-bin
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
# 3.1 修复 qs 与 qt6-base 版本不匹配
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
# 4. 配置显示管理器
# -------------------------------------------------------------
info "配置显示管理器..."

# 启用SDDM（默认）
sudo systemctl enable sddm.service 2>/dev/null || true

# 安装ly但不启用（作为备选）
sudo systemctl disable ly.service 2>/dev/null || true

# -------------------------------------------------------------
# 5. Stow 移植配置
# -------------------------------------------------------------
cd "$REPO_DIR"
info "通过 GNU Stow 移植配置到 \$HOME ..."
for pkg in */; do
    pkg="${pkg%/}"
    case "$pkg" in
        .git|sddm|dms-sysmon|transparent-blur|applications|icons) continue ;;
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
# 6. 配置桌面环境
# -------------------------------------------------------------
info "配置桌面环境..."

# 确保niri配置目录存在
mkdir -p ~/.config/niri
if [[ -d "$REPO_DIR/niri/.config/niri" ]]; then
    cp -r "$REPO_DIR/niri/.config/niri/"* ~/.config/niri/ 2>/dev/null || true
fi

# 确保hyprland配置目录存在
mkdir -p ~/.config/hypr
if [[ -d "$REPO_DIR/hyprland/.config/hypr" ]]; then
    cp -r "$REPO_DIR/hyprland/.config/hypr/"* ~/.config/hypr/ 2>/dev/null || true
fi

# 确保plasma配置目录存在
mkdir -p ~/.config
if [[ -d "$REPO_DIR/plasma/.config" ]]; then
    cp -r "$REPO_DIR/plasma/.config/"* ~/.config/ 2>/dev/null || true
fi

# -------------------------------------------------------------
# 7. 设置默认 shell 为 fish
# -------------------------------------------------------------
if [[ "$(getent passwd "$USER_NAME" | cut -d: -f7)" != "/usr/bin/fish" ]]; then
    info "设置默认 shell 为 fish ..."
    sudo chsh -s /usr/bin/fish "$USER_NAME"
fi

# -------------------------------------------------------------
# 8. 收尾
# -------------------------------------------------------------
if command -v niri >/dev/null && pgrep -x niri >/dev/null; then
    info "niri 正在运行，重载配置 ..."
    niri msg action reload-config || warn "niri 重载失败，请手动执行 niri msg action reload-config"
fi

# -------------------------------------------------------------
# 9. 安装 h 命令到 ~/.local/bin
# -------------------------------------------------------------
if [[ -f "$REPO_DIR/bin/h" ]]; then
    info "安装 h 命令到 ~/.local/bin ..."
    mkdir -p "$HOME/.local/bin"
    cp "$REPO_DIR/bin/h" "$HOME/.local/bin/h"
    chmod +x "$HOME/.local/bin/h"
fi

# -------------------------------------------------------------
# 10. 安装中文帮助包装 (bash/zsh)
# -------------------------------------------------------------
if [[ -d "$REPO_DIR/share/zhhelp" ]]; then
    info "安装中文帮助文件到 ~/.local/share/zhhelp ..."
    mkdir -p "$HOME/.local/share/zhhelp"
    cp "$REPO_DIR/share/zhhelp"/*.txt "$HOME/.local/share/zhhelp/"
fi
if [[ -f "$REPO_DIR/share/zhhelp-wrapper.sh" ]]; then
    info "安装中文帮助包装脚本 ..."
    cp "$REPO_DIR/share/zhhelp-wrapper.sh" "$HOME/.local/share/zhhelp-wrapper.sh"
fi

# -------------------------------------------------------------
# 11. 设置中文 man 手册路径
# -------------------------------------------------------------
MAN_ZH_DIR="$REPO_DIR/share/man-zh"
if [[ -d "$MAN_ZH_DIR" ]]; then
    info "配置中文帮助文件路径 ..."
    mkdir -p "$HOME/.local/share/man-zh"
    cp -r "$MAN_ZH_DIR"/* "$HOME/.local/share/man-zh/"
fi

# -------------------------------------------------------------
# 12. 安装fastfetch绿色版配置
# -------------------------------------------------------------
if [[ -f "$REPO_DIR/fastfetch/.config/fastfetch/config-green.jsonc" ]]; then
    info "安装fastfetch绿色版配置 ..."
    mkdir -p "$HOME/.config/fastfetch"
    cp "$REPO_DIR/fastfetch/.config/fastfetch/config-green.jsonc" "$HOME/.config/fastfetch/config-green.jsonc"
fi
if [[ -f "$REPO_DIR/fastfetch/.local/bin/fastfetch-switch.sh" ]]; then
    mkdir -p "$HOME/.local/bin"
    cp "$REPO_DIR/fastfetch/.local/bin/fastfetch-switch.sh" "$HOME/.local/bin/fastfetch-switch.sh"
    chmod +x "$HOME/.local/bin/fastfetch-switch.sh"
fi

# -------------------------------------------------------------
# 13. 安装hackingtools
# -------------------------------------------------------------
if [[ -d "$REPO_DIR/hackingtools" ]]; then
    info "安装hackingtools ..."
    mkdir -p "$HOME/.local/share/hackingtools"
    cp -r "$REPO_DIR/hackingtools"/* "$HOME/.local/share/hackingtools/"
    
    # 创建符号链接到bin目录
    mkdir -p "$HOME/.local/bin"
    for tool in "$HOME/.local/share/hackingtools/bin/"*; do
        if [[ -f "$tool" ]] || [[ -L "$tool" ]]; then
            ln -sf "$tool" "$HOME/.local/bin/$(basename "$tool")"
        fi
    done
fi

# -------------------------------------------------------------
# 14. 配置环境变量
# -------------------------------------------------------------
info "配置环境变量 ..."
mkdir -p ~/.config/environment.d
cat > ~/.config/environment.d/desktop.conf << 'EOF'
# 桌面环境配置
COLORTERM=truecolor
PATH=$HOME/.local/bin:$HOME/.local/share/hackingtools/bin:$PATH
EOF

# 添加到shell配置
for rc in ~/.bashrc ~/.zshrc ~/.config/fish/config.fish; do
    if [[ -f "$rc" ]]; then
        # 检查是否已添加
        if ! grep -q "hackingtools" "$rc" 2>/dev/null; then
            if [[ "$rc" == *"fish"* ]]; then
                echo "" >> "$rc"
                echo "# hackingtools" >> "$rc"
                echo 'set -gx PATH $HOME/.local/share/hackingtools/bin $PATH' >> "$rc"
            else
                echo "" >> "$rc"
                echo "# hackingtools" >> "$rc"
                echo 'export PATH="$HOME/.local/share/hackingtools/bin:$PATH"' >> "$rc"
            fi
        fi
    fi
done

info "全部完成。默认 shell 为 fish，man 手册为中文（MANPATH 已配置）。"
info "h 命令已安装，输入 h 查看工具速查手册。"
info "hackingtools 已安装，可用工具: $(ls "$HOME/.local/share/hackingtools/bin" 2>/dev/null | wc -l) 个"
info ""
info "更新方法: ./install.sh --update"
