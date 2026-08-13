# grep 中文帮助包装函数
# 注意: grep -h 是正常参数(非帮助), 只有 --help / -help / --h 显示中文帮助
function grep
    for arg in $argv
        if string match -qr '^(--h|-help|--help|-\?)$' -- $arg
            command cat ~/.config/fish/zhhelp/grep.txt 2>/dev/null; or echo "暂无中文帮助: grep"
            return 0
        end
    end
    command grep $argv
end
