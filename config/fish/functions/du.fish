# du 中文帮助包装函数
# 注意: du -h 是正常参数(非帮助), 只有 --help / -help / --h 显示中文帮助
function du
    for arg in $argv
        if string match -qr '^(--h|-help|--help|-\?)$' -- $arg
            command cat ~/.config/fish/zhhelp/du.txt 2>/dev/null; or echo "暂无中文帮助: du"
            return 0
        end
    end
    command du $argv
end
