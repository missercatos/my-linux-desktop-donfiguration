# chmod 中文帮助包装函数
# 用法: 正常使用 chmod; 输入 chmod -h / --help / -help 时显示中文帮助和常用指令集
function chmod
    for arg in $argv
        if string match -qr '^(-h|--h|-help|--help|-\?)$' -- $arg
            command cat ~/.config/fish/zhhelp/chmod.txt 2>/dev/null; or echo "暂无中文帮助: chmod"
            return 0
        end
    end
    command chmod $argv
end
