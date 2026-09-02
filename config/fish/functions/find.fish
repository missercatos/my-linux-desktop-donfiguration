# find 中文帮助包装函数
# 用法: 正常使用 find; 输入 find -h / --help / -help 时显示中文帮助和常用指令集
function find
    for arg in $argv
        if string match -qr '^(-h|--h|-help|--help|-\?)$' -- $arg
            command cat ~/.config/fish/zhhelp/find.txt 2>/dev/null; or echo "暂无中文帮助: find"
            return 0
        end
    end
    command find $argv
end
