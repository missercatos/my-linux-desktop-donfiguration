function gh
    for arg in $argv
        if string match -qr '^(-h|--h|-help|--help|-\?)$' -- $arg
            command cat ~/.config/fish/zhhelp/gh.txt; or echo "暂无中文帮助: gh"
            return 0
        end
    end
    command gh $argv
end
