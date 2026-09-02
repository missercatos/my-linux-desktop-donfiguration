# curl 中文帮助包装函数
# 用法: 正常使用 curl; 输入 curl -h / --help / -help 时显示中文帮助和常用指令集
function curl
    for arg in $argv
        if string match -qr '^(-h|--h|-help|--help|-\?)$' -- $arg
            command cat ~/.config/fish/zhhelp/curl.txt 2>/dev/null; or echo "暂无中文帮助: curl"
            return 0
        end
    end
    command curl $argv
end
