# cp 中文帮助包装函数
# 用法: 正常使用 cp; 输入 cp -h / --help / -help 时显示中文帮助和常用指令集
function cp
    for arg in $argv
        if string match -qr '^(-h|--h|-help|--help|-\?)$' -- $arg
            command cat ~/.config/fish/zhhelp/cp.txt 2>/dev/null; or echo "暂无中文帮助: cp"
            return 0
        end
    end
    command cp $argv
end
