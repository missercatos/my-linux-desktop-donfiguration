function mpv
    for arg in $argv
        if string match -qr '^(-h|--h|-help|--help|-\?)$' -- $arg
            command cat ~/.config/fish/zhhelp/mpv.txt; or echo "暂无中文帮助: mpv"
            return 0
        end
    end
    command mpv $argv
end
