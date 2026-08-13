function yay
    for arg in $argv
        if string match -qr '^(-h|--h|-help|--help|-\?)$' -- $arg
            command cat ~/.config/fish/zhhelp/yay.txt; or echo "暂无中文帮助: yay"
            return 0
        end
    end
    command yay $argv
end
