function paru
    for arg in $argv
        if string match -qr '^(-h|--h|-help|--help|-\?)$' -- $arg
            command cat ~/.config/fish/zhhelp/paru.txt; or echo "暂无中文帮助: paru"
            return 0
        end
    end
    command paru $argv
end
