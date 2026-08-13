# unzip 中文帮助包装函数
# 用法: 正常使用 unzip; 输入 unzip -h / --help / -help 时显示中文帮助和常用指令集
function unzip
    for arg in $argv
        if string match -qr '^(-h|--h|-help|--help|-\?)$' -- $arg
            command cat ~/.config/fish/zhhelp/unzip.txt 2>/dev/null; or echo "暂无中文帮助: unzip"
            return 0
        end
    end
    command unzip $argv
end
