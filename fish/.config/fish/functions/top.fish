# top 中文帮助包装函数
# 用法: 正常使用 top; 输入 top -h / --help / -help 时显示中文帮助和常用指令集
function top
    for arg in $argv
        if string match -qr '^(-h|--h|-help|--help|-\?)$' -- $arg
            command cat ~/.config/fish/zhhelp/top.txt 2>/dev/null; or echo "暂无中文帮助: top"
            return 0
        end
    end
    command top $argv
end
