# awk 中文帮助包装函数
# 用法: 正常使用 awk; 输入 awk -h / --help / -help 时显示中文帮助和常用指令集
function awk
    for arg in $argv
        if string match -qr '^(-h|--h|-help|--help|-\?)$' -- $arg
            command cat ~/.config/fish/zhhelp/awk.txt 2>/dev/null; or echo "暂无中文帮助: awk"
            return 0
        end
    end
    command awk $argv
end
