function fzf
    for arg in $argv
        if string match -qr '^(-h|--h|-help|--help|-\?)$' -- $arg
            command cat ~/.config/fish/zhhelp/fzf.txt; or echo "暂无中文帮助: fzf"
            return 0
        end
    end
    command fzf $argv
end
