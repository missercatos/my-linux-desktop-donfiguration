function grim
    for arg in $argv
        if string match -qr '^(-h|--h|-help|--help|-\?)$' -- $arg
            command cat ~/.config/fish/zhhelp/grim.txt; or echo "暂无中文帮助: grim"
            return 0
        end
    end
    command grim $argv
end
