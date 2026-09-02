function ip
    for arg in $argv
        if string match -qr '^(-h|--h|-help|--help|-\?)$' -- $arg
            command cat ~/.config/fish/zhhelp/ip.txt; or echo "暂无中文帮助: ip"
            return 0
        end
    end
    command ip $argv
end
