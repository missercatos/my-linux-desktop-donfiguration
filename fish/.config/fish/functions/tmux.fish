function tmux
    for arg in $argv
        if string match -qr '^(-h|--h|-help|--help|-\?)$' -- $arg
            command cat ~/.config/fish/zhhelp/tmux.txt; or echo "暂无中文帮助: tmux"
            return 0
        end
    end
    command tmux $argv
end
