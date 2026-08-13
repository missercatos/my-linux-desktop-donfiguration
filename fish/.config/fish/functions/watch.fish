function watch
    for arg in $argv
        if string match -qr '^(-h|--h|-help|--help|-\?)$' -- $arg
            command cat ~/.config/fish/zhhelp/watch.txt; or echo "暂无中文帮助: watch"
            return 0
        end
    end
    command watch $argv
end
