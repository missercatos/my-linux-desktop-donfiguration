# sed 中文帮助包装函数
# 用法: 正常使用 sed; 输入 sed -h / --help / -help 时显示中文帮助和常用指令集
function sed
    for arg in $argv
        if string match -qr '^(-h|--h|-help|--help|-\?)$' -- $arg
            command cat ~/.config/fish/zhhelp/sed.txt 2>/dev/null; or echo "暂无中文帮助: sed"
            return 0
        end
    end
    command sed $argv
end
