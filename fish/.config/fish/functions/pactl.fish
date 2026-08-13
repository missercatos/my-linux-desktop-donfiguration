function pactl
    for arg in $argv
        if string match -qr '^(-h|--h|-help|--help|-\?)$' -- $arg
            command cat ~/.config/fish/zhhelp/pactl.txt; or echo "暂无中文帮助: pactl"
            return 0
        end
    end
    command pactl $argv
end
