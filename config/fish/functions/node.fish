function node
    for arg in $argv
        if string match -qr '^(-h|--h|-help|--help|-\?)$' -- $arg
            command cat ~/.config/fish/zhhelp/node.txt; or echo "暂无中文帮助: node"
            return 0
        end
    end
    command node $argv
end
