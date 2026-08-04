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
setopt AUTO_CD MENU_COMPLETE EXTENDED_GLOB

f() { fastfetch -c ~/.config/tactical/fastfetch.jsonc "$@"; }

# 禁用干扰性玩笑程序（战略终端专注）
_tactical_nope() { echo "战术终端已禁用: $1" >&2; return 127 }
for _c in sl cowsay cowthink fortune figlet toilet xcowsay oneko bb; do
  alias "$_c"="_tactical_nope $_c"
done
unset _c
