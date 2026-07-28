#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

export PATH="/bin:/usr/bin:$PATH"
alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

if [ -z "$DISPLAY" ] && [ -z "$WAYLAND_DISPLAY" ]; then
    export LANG=zh_CN.UTF-8
fi

. "/home/a/.acme.sh/acme.sh.env"
