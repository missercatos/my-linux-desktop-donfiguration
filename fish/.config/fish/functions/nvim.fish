function nvim
    for arg in $argv
        if string match -qr '^(-h|--h|-help|--help|-\?)$' -- $arg
            command cat ~/.config/fish/zhhelp/nvim.txt; or echo "暂无中文帮助: nvim"
            return 0
        end
    end
    command nvim $argv
end
