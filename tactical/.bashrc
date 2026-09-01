#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Unified environment for all terminals
export STARSHIP_CONFIG="$HOME/.config/tactical/starship.toml"
export ZDOTDIR="$HOME/.config/tactical/zsh"

export PATH="/bin:/usr/bin:$PATH"
alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

if [ -z "$DISPLAY" ] && [ -z "$WAYLAND_DISPLAY" ]; then
    export LANG=zh_CN.UTF-8
fi

. "/home/a/.acme.sh/acme.sh.env"

# ── 中文帮助包装 (拦截 -h 显示中文) ──
[[ -f ~/.local/share/zhhelp-wrapper.sh ]] && source ~/.local/share/zhhelp-wrapper.sh

# fastfetch自动检测TTY配置
if [[ -f ~/.local/bin/fastfetch-switch.sh ]]; then
    alias fastfetch='~/.local/bin/fastfetch-switch.sh auto'
fi

# Auto-generate starship config based on cava theme
if [[ -f ~/.local/bin/generate-starship-config ]]; then
    ~/.local/bin/generate-starship-config >/dev/null 2>&1
fi
