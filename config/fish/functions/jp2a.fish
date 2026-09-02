# jp2a 中文帮助包装函数
# 用法: 正常使用 jp2a; 输入 jp2a -h / --help / -help 时显示中文帮助和常用指令集
function jp2a
    for arg in $argv
        if string match -qr '^(-h|--h|-help|--help|-\?)$' -- $arg
            command cat ~/.config/fish/zhhelp/jp2a.txt 2>/dev/null; or echo "暂无中文帮助: jp2a"
            return 0
        end
    end
    command jp2a $argv
end
