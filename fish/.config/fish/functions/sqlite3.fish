function sqlite3
    for arg in $argv
        if string match -qr '^(-h|--h|-help|--help|-\?)$' -- $arg
            command cat ~/.config/fish/zhhelp/sqlite3.txt; or echo "暂无中文帮助: sqlite3"
            return 0
        end
    end
    command sqlite3 $argv
end
