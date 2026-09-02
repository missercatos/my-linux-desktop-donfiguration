# bzip2 中文帮助包装函数
# 用法: 正常使用 bzip2; 输入 bzip2 -h / --help / -help 时显示中文帮助和常用指令集
function bzip2
    for arg in $argv
        if string match -qr '^(-h|--h|-help|--help|-\?)$' -- $arg
            command cat ~/.config/fish/zhhelp/bzip2.txt 2>/dev/null; or echo "暂无中文帮助: bzip2"
            return 0
        end
    end
    command bzip2 $argv
end
