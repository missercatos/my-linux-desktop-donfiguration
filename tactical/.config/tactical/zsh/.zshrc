# tactical/zsh/.zshrc - 独立TUI配置（荧光绿色系）
# 仅用于foot/tmux，不依赖DMS

# ── Vi模式 ──
bindkey -v

function _zsh_cursor {
  case $KEYMAP in
    vicmd)     printf '\e[2 q';;
    viins|main) printf '\e[6 q';;
  esac
}
zle -N zsh-keymap-select _zsh_cursor
zle -N zsh-line-init _zsh_cursor

bindkey -M viins 'jk' vi-cmd-mode
bindkey -M viins 'kj' vi-cmd-mode

# ── Starship提示符 ──
eval "$(starship init zsh)"

# ── 旋转动画钩子 ──
[[ -f ~/.local/bin/spinner-hook.sh ]] && source ~/.local/bin/spinner-hook.sh

# ── 历史记录 ──
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE HIST_REDUCE_BLANKS

# ── 补全系统 ──
autoload -Uz compinit && compinit

# 补全菜单样式
zstyle ':completion:*' menu select
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*:warnings' format '没有匹配项'
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'

# 补全颜色（荧光绿）
zstyle ':completion:*' list-colors 'di:#33ff33' 'ln:#66ff66' 'so:#99ff99' 'ex:#33ff33' 'bd:#33ff33' 'cd:#33ff33' 'pi:#33ff33' 'si:#33ff33' 'tw:#002200' 'ow:#002200'

# Tab补全行为
setopt AUTO_CD MENU_COMPLETE EXTENDED_GLOB
zstyle ':completion:*' menu yes select

# ── zsh-autocomplete灰色建议 ──
if [[ -f /usr/share/zsh/plugins/zsh-autocomplete/zsh-autocomplete.plugin.zsh ]]; then
    source /usr/share/zsh/plugins/zsh-autocomplete/zsh-autocomplete.plugin.zsh
fi

# ── 语法高亮 ──
if [[ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
    source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# ── 自动建议 ──
if [[ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
    source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#66ff66'
fi

# ── 中文帮助包装 ──
[[ -f ~/.local/share/zhhelp-wrapper.sh ]] && source ~/.local/share/zhhelp-wrapper.sh

# ── 快捷别名 ──
alias ls='ls --color=auto'
alias ll='ls -la'
alias grep='grep --color=auto'
alias cat='bat --paging=never'
alias tree='tree --dirsfirst'
