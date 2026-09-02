# git 中文帮助包装函数
# 用法: 正常使用 git; 输入 git -h / --help / -help 时显示中文帮助和常用指令集
function git
    for arg in $argv
        if string match -qr '^(-h|--h|-help|--help|-\?)$' -- $arg
            command cat ~/.config/fish/zhhelp/git.txt 2>/dev/null; or echo "暂无中文帮助: git"
            return 0
        end
    end
    command git $argv
end
