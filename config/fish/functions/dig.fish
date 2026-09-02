function dig
    for arg in $argv
        if string match -qr '^(-h|--h|-help|--help|-\?)$' -- $arg
            command cat ~/.config/fish/zhhelp/dig.txt; or echo "暂无中文帮助: dig"
            return 0
        end
    end
    command dig $argv
end
