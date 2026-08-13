# gzip 中文帮助包装函数
# 用法: 正常使用 gzip; 输入 gzip -h / --help / -help 时显示中文帮助和常用指令集
function gzip
    for arg in $argv
        if string match -qr '^(-h|--h|-help|--help|-\?)$' -- $arg
            command cat ~/.config/fish/zhhelp/gzip.txt 2>/dev/null; or echo "暂无中文帮助: gzip"
            return 0
        end
    end
    command gzip $argv
end
