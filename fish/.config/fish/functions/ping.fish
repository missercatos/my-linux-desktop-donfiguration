# ping 中文帮助包装函数
# 用法: 正常使用 ping; 输入 ping -h / --help / -help 时显示中文帮助和常用指令集
function ping
    for arg in $argv
        if string match -qr '^(-h|--h|-help|--help|-\?)$' -- $arg
            command cat ~/.config/fish/zhhelp/ping.txt 2>/dev/null; or echo "暂无中文帮助: ping"
            return 0
        end
    end
    command ping $argv
end
