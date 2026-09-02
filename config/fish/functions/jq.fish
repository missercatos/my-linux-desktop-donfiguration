function jq
    for arg in $argv
        if string match -qr '^(-h|--h|-help|--help|-\?)$' -- $arg
            command cat ~/.config/fish/zhhelp/jq.txt; or echo "暂无中文帮助: jq"
            return 0
        end
    end
    command jq $argv
end
