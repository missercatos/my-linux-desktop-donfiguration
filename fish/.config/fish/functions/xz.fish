# xz 中文帮助包装函数
# 用法: 正常使用 xz; 输入 xz -h / --help / -help 时显示中文帮助和常用指令集
function xz
    for arg in $argv
        if string match -qr '^(-h|--h|-help|--help|-\?)$' -- $arg
            command cat ~/.config/fish/zhhelp/xz.txt 2>/dev/null; or echo "暂无中文帮助: xz"
            return 0
        end
    end
    command xz $argv
end
