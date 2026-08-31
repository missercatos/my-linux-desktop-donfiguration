#!/usr/bin/env bash
# =============================================================
# TUI System Configuration Script
# TUI config only, fluorescent green theme
# Usage: ./install-tty.sh [--update]
# =============================================================
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_NAME="${SUDO_USER:-$USER}"

# -------------------------------------------------------------
# Info functions (English only)
# -------------------------------------------------------------
info() { printf '\033[1;32m[tty-install]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[tty-warning]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[tty-error]\033[0m %s\n' "$*" >&2; exit 1; }

# -------------------------------------------------------------
# 0. Auto Update
# -------------------------------------------------------------
if [[ "${1:-}" == "--update" ]]; then
    info "Pulling latest config from GitHub..."
    cd "$REPO_DIR"
    git pull origin main || die "Pull failed, check network"
    info "Config updated, please re-run script"
    exit 0
fi

# -------------------------------------------------------------
# 0.1 Pacman Auto Repair
# -------------------------------------------------------------
repair_pacman() {
    info "Checking and repairing pacman..."
    
    # 1. Check and repair keyring
    if [[ -d /etc/pacman.d/gnupg ]]; then
        if ! sudo pacman-key --list-keys &>/dev/null; then
            warn "Keyring corrupted, reinitializing..."
            sudo rm -rf /etc/pacman.d/gnupg
            sudo pacman-key --init
        fi
    else
        info "Initializing pacman keyring..."
        sudo pacman-key --init
    fi
    
    # 2. Populate archlinux keyring
    sudo pacman-key --populate archlinux 2>/dev/null || true
    
    # 3. Import archlinuxcn key if repo exists
    if grep -q "^\[archlinuxcn\]" /etc/pacman.conf 2>/dev/null; then
        info "Importing archlinuxcn key..."
        sudo pacman-key --recv-keys 74F4207F0D0BC945E4AB5F78FE748387E4596636 2>/dev/null || true
        sudo pacman-key --lsign-key 74F4207F0D0BC945E4AB5F78FE748387E4596636 2>/dev/null || true
    fi
    
    # 4. Clean and rebuild package database
    info "Rebuilding package database..."
    sudo rm -f /var/lib/pacman/sync/*.db 2>/dev/null || true
    sudo pacman -Syy --noconfirm
    
    # 5. Verify SigLevel in pacman.conf
    if ! grep -q "^SigLevel.*=.*Required DatabaseOptional" /etc/pacman.conf 2>/dev/null; then
        warn "Fixing SigLevel in pacman.conf..."
        sudo sed -i 's/^#SigLevel\s*=/SigLevel =/' /etc/pacman.conf
        sudo sed -i 's/^SigLevel\s*=\s*$/SigLevel = Required DatabaseOptional/' /etc/pacman.conf
    fi
    
    info "Pacman repair completed"
}

# -------------------------------------------------------------
# 0.2 Mirror Configuration (SJTU - only working mirror)
# -------------------------------------------------------------
configure_mirrors() {
    info "Configuring mirror (SJTU)..."
    
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
    info "Initializing pacman keys..."
    sudo pacman-key --init 2>/dev/null || true
    sudo pacman-key --populate archlinux 2>/dev/null || true
    
    # Force refresh package database
    info "Refreshing package database..."
    sudo pacman -Syy --noconfirm
    
    info "Mirror configured: $mirror"
}

# -------------------------------------------------------------
# 1. Repair Pacman and Configure Mirror
# -------------------------------------------------------------
repair_pacman
configure_mirrors

# -------------------------------------------------------------
# 2. Install TUI Software
# -------------------------------------------------------------
TTY_PKGS=(
    # Terminal
    foot alacritty tmux zsh zellij
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

info "Installing TUI packages..."
sudo pacman -S --needed --noconfirm "${TTY_PKGS[@]}" || {
    warn "Some packages failed, continuing..."
}

# -------------------------------------------------------------
# 3. Check AUR Helper Status
# -------------------------------------------------------------
if command -v yay &>/dev/null; then
    info "yay installed: $(yay --version)"
else
    warn "yay not installed, install AUR helper manually"
    warn "Recommended: sudo pacman -S yay or sudo pacman -S paru"
    warn "AUR functions will be unavailable"
fi

# -------------------------------------------------------------
# 4. Deploy foot Config
# -------------------------------------------------------------
info "Deploying foot config..."
mkdir -p ~/.config/foot
cp "$REPO_DIR/foot/.config/foot/foot.ini" ~/.config/foot/foot.ini

# -------------------------------------------------------------
# 5. Deploy alacritty Config
# -------------------------------------------------------------
info "Deploying alacritty config..."
mkdir -p ~/.config/alacritty
cp "$REPO_DIR/alacritty/.config/alacritty/alacritty.toml" ~/.config/alacritty/alacritty.toml

# -------------------------------------------------------------
# 6. Deploy tmux Config
# -------------------------------------------------------------
info "Deploying tmux config..."
cp "$REPO_DIR/tmux/.tmux.conf" ~/.tmux.conf

# -------------------------------------------------------------
# 7. Deploy zellij Config
# -------------------------------------------------------------
info "Deploying zellij config..."
mkdir -p ~/.config/zellij
mkdir -p ~/.config/zellij/themes
mkdir -p ~/.config/zellij/layouts
if [[ -f "$REPO_DIR/zellij/.config/zellij/config.kdl" ]]; then
    cp "$REPO_DIR/zellij/.config/zellij/config.kdl" ~/.config/zellij/config.kdl
fi
if [[ -f "$REPO_DIR/zellij/.config/zellij/themes/green-tty.kdl" ]]; then
    cp "$REPO_DIR/zellij/.config/zellij/themes/green-tty.kdl" ~/.config/zellij/themes/green-tty.kdl
fi
if [[ -f "$REPO_DIR/zellij/.config/zellij/layouts/green-tty.kdl" ]]; then
    cp "$REPO_DIR/zellij/.config/zellij/layouts/green-tty.kdl" ~/.config/zellij/layouts/green-tty.kdl
fi

# -------------------------------------------------------------
# 8. Deploy yazi Config
# -------------------------------------------------------------
info "Deploying yazi config..."
mkdir -p ~/.config/yazi
cp "$REPO_DIR/yazi/.config/yazi/theme.toml" ~/.config/yazi/theme.toml

# -------------------------------------------------------------
# 9. Deploy btop Config
# -------------------------------------------------------------
info "Deploying btop config..."
mkdir -p ~/.config/btop
mkdir -p ~/.config/btop/themes
cp "$REPO_DIR/btop/.config/btop/"* ~/.config/btop/ 2>/dev/null || true

# Deploy btop TTY green theme
if [[ -f "$REPO_DIR/btop/.config/btop/themes/green-tty.theme" ]]; then
    info "Deploying btop TTY theme..."
    cp "$REPO_DIR/btop/.config/btop/themes/green-tty.theme" ~/.config/btop/themes/green-tty.theme
fi
if [[ -f "$REPO_DIR/btop/.config/btop/btop-tty.conf" ]]; then
    cp "$REPO_DIR/btop/.config/btop/btop-tty.conf" ~/.config/btop/btop-tty.conf
fi

# -------------------------------------------------------------
# 10. Deploy starship Config
# -------------------------------------------------------------
info "Deploying starship config..."
cp "$REPO_DIR/starship/.config/starship.toml.custom" ~/.config/starship.toml.custom 2>/dev/null || true

# -------------------------------------------------------------
# 11. Deploy tactical Config (independent green theme)
# -------------------------------------------------------------
info "Deploying tactical config..."
mkdir -p ~/.config/tactical/zsh
mkdir -p ~/.config/tactical/tty
cp "$REPO_DIR/tactical/.config/tactical/starship.toml" ~/.config/tactical/starship.toml
cp "$REPO_DIR/tactical/.config/tactical/tty/starship.toml" ~/.config/tactical/tty/starship.toml 2>/dev/null || true
cp "$REPO_DIR/tactical/.config/tactical/zsh/.zshrc" ~/.config/tactical/zsh/.zshrc

# Deploy neovim TTY green theme
if [[ -d "$REPO_DIR/nvim/.config/nvim" ]]; then
    info "Deploying neovim TTY theme..."
    mkdir -p ~/.config/nvim/lua/config
    cp "$REPO_DIR/nvim/.config/nvim/lua/config/tty-theme.lua" ~/.config/nvim/lua/config/tty-theme.lua 2>/dev/null || true
    if [[ -f "$REPO_DIR/nvim/.config/nvim/init.lua" ]]; then
        cp "$REPO_DIR/nvim/.config/nvim/init.lua" ~/.config/nvim/init.lua
    fi
fi

# -------------------------------------------------------------
# 12. Deploy bash Config
# -------------------------------------------------------------
info "Deploying bash config..."
cp "$REPO_DIR/bash/.bashrc" ~/.bashrc 2>/dev/null || true

# -------------------------------------------------------------
# 13. Deploy zsh Config
# -------------------------------------------------------------
info "Deploying zsh config..."
cp "$REPO_DIR/zsh/.zshrc" ~/.zshrc 2>/dev/null || true

# -------------------------------------------------------------
# 14. Install all bin scripts
# -------------------------------------------------------------
if [[ -d "$REPO_DIR/bin" ]]; then
    info "Installing bin scripts..."
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
        info "Installing ${script} script..."
        mkdir -p ~/.local/bin
        cp "$REPO_DIR/$script" ~/.local/bin/
        chmod +x ~/.local/bin/"$script"
    fi
done

# -------------------------------------------------------------
# 15. Install fastfetch green config
# -------------------------------------------------------------
if [[ -f "$REPO_DIR/fastfetch/.config/fastfetch/config-green.jsonc" ]]; then
    info "Deploying fastfetch green config..."
    mkdir -p ~/.config/fastfetch
    cp "$REPO_DIR/fastfetch/.config/fastfetch/config-green.jsonc" ~/.config/fastfetch/config-green.jsonc
fi
if [[ -f "$REPO_DIR/fastfetch/.local/bin/fastfetch-switch.sh" ]]; then
    mkdir -p ~/.local/bin
    cp "$REPO_DIR/fastfetch/.local/bin/fastfetch-switch.sh" ~/.local/bin/fastfetch-switch.sh
    chmod +x ~/.local/bin/fastfetch-switch.sh
fi

# -------------------------------------------------------------
# 16. Install hackingtools
# -------------------------------------------------------------
if [[ -d "$REPO_DIR/hackingtools" ]]; then
    info "Installing hackingtools..."
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
# 17. Set default shell to zsh
# -------------------------------------------------------------
if [[ "$(getent passwd "$USER_NAME" | cut -d: -f7)" != "/usr/bin/zsh" ]]; then
    info "Setting default shell to zsh..."
    sudo chsh -s /usr/bin/zsh "$USER_NAME"
fi

# -------------------------------------------------------------
# 18. Configure Environment Variables
# -------------------------------------------------------------
info "Configuring environment variables..."
mkdir -p ~/.config/environment.d
cat > ~/.config/environment.d/tty.conf << 'EOF'
# TTY config - fluorescent green theme
# Use ASCII-only starship config for pure TTY
STARSHIP_CONFIG=$HOME/.config/tactical/tty/starship.toml
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
            echo 'export STARSHIP_CONFIG="$HOME/.config/tactical/tty/starship.toml"' >> "$rc"
            echo 'export ZDOTDIR="$HOME/.config/tactical/zsh"' >> "$rc"
        fi
        # Add hackingtools to PATH if not present
        if ! grep -q "hackingtools" "$rc" 2>/dev/null; then
            echo 'export PATH="$HOME/.local/bin:$HOME/.local/share/hackingtools/bin:$PATH"' >> "$rc"
        fi
        # Add fastfetch alias if not present
        if ! grep -q "fastfetch-switch.sh" "$rc" 2>/dev/null; then
            echo "" >> "$rc"
            echo "# fastfetch TTY auto-detect" >> "$rc"
            echo 'if [[ -f ~/.local/bin/fastfetch-switch.sh ]]; then' >> "$rc"
            echo "    alias fastfetch='~/.local/bin/fastfetch-switch.sh auto'" >> "$rc"
            echo 'fi' >> "$rc"
        fi
    fi
done

info "All done!"
info "Please re-login or run:"
info "  source ~/.config/tactical/zsh/.zshrc"
info "  tmux source-file ~/.tmux.conf"
