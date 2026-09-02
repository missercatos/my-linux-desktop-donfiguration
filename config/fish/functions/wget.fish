# wget 中文帮助包装函数
# 用法: 正常使用 wget; 输入 wget -h / --help / -help 时显示中文帮助和常用指令集
function wget
    for arg in $argv
        if string match -qr '^(-h|--h|-help|--help|-\?)$' -- $arg
            command cat ~/.config/fish/zhhelp/wget.txt 2>/dev/null; or echo "暂无中文帮助: wget"
            return 0
        end
    end
    command wget $argv
end
