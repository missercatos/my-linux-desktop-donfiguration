function yazi
    for arg in $argv
        if string match -qr '^(-h|--h|-help|--help|-\?)$' -- $arg
            command cat ~/.config/fish/zhhelp/yazi.txt; or echo "暂无中文帮助: yazi"
            return 0
        end
    end
    command yazi $argv
end
