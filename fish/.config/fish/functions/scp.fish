# scp 中文帮助包装函数
# 用法: 正常使用 scp; 输入 scp -h / --help / -help 时显示中文帮助和常用指令集
function scp
    for arg in $argv
        if string match -qr '^(-h|--h|-help|--help|-\?)$' -- $arg
            command cat ~/.config/fish/zhhelp/scp.txt 2>/dev/null; or echo "暂无中文帮助: scp"
            return 0
        end
    end
    command scp $argv
end
