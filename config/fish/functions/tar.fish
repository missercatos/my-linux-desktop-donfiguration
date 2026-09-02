# tar 中文帮助包装函数
# 用法: 正常使用 tar; 输入 tar -h / --help / -help 时显示中文帮助和常用指令集
function tar
    for arg in $argv
        if string match -qr '^(-h|--h|-help|--help|-\?)$' -- $arg
            command cat ~/.config/fish/zhhelp/tar.txt 2>/dev/null; or echo "暂无中文帮助: tar"
            return 0
        end
    end
    command tar $argv
end
