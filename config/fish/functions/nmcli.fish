function nmcli
    for arg in $argv
        if string match -qr '^(-h|--h|-help|--help|-\?)$' -- $arg
            command cat ~/.config/fish/zhhelp/nmcli.txt; or echo "暂无中文帮助: nmcli"
            return 0
        end
    end
    command nmcli $argv
end
