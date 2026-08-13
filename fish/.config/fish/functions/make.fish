function make
    for arg in $argv
        if string match -qr '^(-h|--h|-help|--help|-\?)$' -- $arg
            command cat ~/.config/fish/zhhelp/make.txt; or echo "暂无中文帮助: make"
            return 0
        end
    end
    command make $argv
end
