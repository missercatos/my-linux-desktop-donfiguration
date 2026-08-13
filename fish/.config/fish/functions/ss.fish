function ss
    for arg in $argv
        if string match -qr '^(-h|--h|-help|--help|-\?)$' -- $arg
            command cat ~/.config/fish/zhhelp/ss.txt; or echo "暂无中文帮助: ss"
            return 0
        end
    end
    command ss $argv
end
