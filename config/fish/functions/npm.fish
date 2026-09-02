function npm
    for arg in $argv
        if string match -qr '^(-h|--h|-help|--help|-\?)$' -- $arg
            command cat ~/.config/fish/zhhelp/npm.txt; or echo "暂无中文帮助: npm"
            return 0
        end
    end
    command npm $argv
end
