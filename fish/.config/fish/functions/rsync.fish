# rsync 中文帮助包装函数
# 用法: 正常使用 rsync; 输入 rsync -h / --help / -help 时显示中文帮助和常用指令集
function rsync
    for arg in $argv
        if string match -qr '^(-h|--h|-help|--help|-\?)$' -- $arg
            command cat ~/.config/fish/zhhelp/rsync.txt 2>/dev/null; or echo "暂无中文帮助: rsync"
            return 0
        end
    end
    command rsync $argv
end
