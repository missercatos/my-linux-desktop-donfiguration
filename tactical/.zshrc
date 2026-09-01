# Unified shell config for all terminals
export STARSHIP_CONFIG="$HOME/.config/tactical/starship.toml"
export ZDOTDIR="$HOME/.config/tactical/zsh"

bindkey -v

function _zsh_cursor {
  case $KEYMAP in
    vicmd)     printf '\e[2 q';;
    viins|main) printf '\e[6 q';;
  esac
}
zle -N zle-keymap-select _zsh_cursor
zle -N zle-line-init _zsh_cursor

bindkey -M viins 'jk' vi-cmd-mode
bindkey -M viins 'kj' vi-cmd-mode

eval "$(starship init zsh)"

HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE HIST_REDUCE_BLANKS

zstyle ':completion:*' menu yes select
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '[%d]'
setopt AUTO_CD MENU_COMPLETE EXTENDED_GLOB

() {
  local colors=()
  local src="$HOME/.config/cava/config"

  if [[ -f "$src" ]]; then
    local theme line
    while IFS= read -r line; do
      theme="${line#theme = \'}"
      theme="${theme%%\'*}"
      [[ -n "$theme" ]] && break
    done < "$src"
    [[ -n "$theme" && -f "$HOME/.config/cava/themes/$theme" ]] && src="$HOME/.config/cava/themes/$theme"

    local i=1 c
    while true; do
      c=$(sed -n "s/.*gradient_color_$i *= *'\(.*\)'/\1/p" "$src" 2>/dev/null | head -1)
      [[ -z "$c" ]] && break
      colors+=("$c")
      ((i++))
    done
  fi

  if [[ ${#colors[@]} -eq 0 ]]; then
    colors=('#7dcfff' '#7aa2f7' '#bb9af7' '#f7768e' '#ff9e64')
  fi

  local c1="${colors[1]}" c2="${colors[2]:-$c1}" c3="${colors[3]:-$c2}"
  local c4="${colors[4]:-$c1}" c5="${colors[5]:-$c2}"

  ZSH_HIGHLIGHT_STYLES=()
  ZSH_HIGHLIGHT_STYLES[default]='none'
  ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=red,bold'
  ZSH_HIGHLIGHT_STYLES[reserved-word]="fg=$c1"
  ZSH_HIGHLIGHT_STYLES[alias]="fg=$c1"
  ZSH_HIGHLIGHT_STYLES[builtin]="fg=$c1"
  ZSH_HIGHLIGHT_STYLES[function]="fg=$c1"
  ZSH_HIGHLIGHT_STYLES[command]="fg=$c1"
  ZSH_HIGHLIGHT_STYLES[precommand]="fg=$c1"
  ZSH_HIGHLIGHT_STYLES[hashed-command]="fg=$c1"
  ZSH_HIGHLIGHT_STYLES[path]="fg=$c2"
  ZSH_HIGHLIGHT_STYLES[path_prefix]='none'
  ZSH_HIGHLIGHT_STYLES[path_approx]="fg=$c3"
  ZSH_HIGHLIGHT_STYLES[globbing]="fg=$c3"
  ZSH_HIGHLIGHT_STYLES[history-expansion]="fg=$c5"
  ZSH_HIGHLIGHT_STYLES[single-hyphen-option]="fg=$c3"
  ZSH_HIGHLIGHT_STYLES[double-hyphen-option]="fg=$c3"
  ZSH_HIGHLIGHT_STYLES[back-quoted-argument]="fg=$c4"
  ZSH_HIGHLIGHT_STYLES[single-quoted-argument]="fg=$c4"
  ZSH_HIGHLIGHT_STYLES[double-quoted-argument]="fg=$c4"
  ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]="fg=$c4"
  ZSH_HIGHLIGHT_STYLES[rc-quotes]="fg=$c3"
  ZSH_HIGHLIGHT_STYLES[assign]="fg=$c5"
  ZSH_HIGHLIGHT_STYLES[redirection]="fg=$c3"
  ZSH_HIGHLIGHT_STYLES[comment]='fg=gray'
  ZSH_HIGHLIGHT_STYLES[variable]="fg=$c5"
  ZSH_HIGHLIGHT_STYLES[mathnum]="fg=$c2"
  ZSH_HIGHLIGHT_STYLES[matherror]='fg=red,bold'
}

ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#444444'

source /usr/share/zsh/plugins/zsh-autocomplete/zsh-autocomplete.plugin.zsh
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

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
