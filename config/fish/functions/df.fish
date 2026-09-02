# df 中文帮助包装函数
# 注意: df -h 是正常参数(非帮助), 只有 --help / -help / --h 显示中文帮助
function df
    for arg in $argv
        if string match -qr '^(--h|-help|--help|-\?)$' -- $arg
            command cat ~/.config/fish/zhhelp/df.txt 2>/dev/null; or echo "暂无中文帮助: df"
            return 0
        end
    end
    command df $argv
end
