# chafa 中文帮助包装函数
# 用法: 正常使用 chafa; 输入 chafa -h / --help / -help 时显示中文帮助和常用指令集
function chafa
    for arg in $argv
        if string match -qr '^(-h|--h|-help|--help|-\?)$' -- $arg
            command cat ~/.config/fish/zhhelp/chafa.txt 2>/dev/null; or echo "暂无中文帮助: chafa"
            return 0
        end
    end
    command chafa $argv
end
