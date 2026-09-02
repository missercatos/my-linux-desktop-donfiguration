function gdb
    for arg in $argv
        if string match -qr '^(-h|--h|-help|--help|-\?)$' -- $arg
            command cat ~/.config/fish/zhhelp/gdb.txt; or echo "暂无中文帮助: gdb"
            return 0
        end
    end
    command gdb $argv
end
