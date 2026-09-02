# ffmpeg 中文帮助包装函数
# 用法: 正常使用 ffmpeg; 输入 ffmpeg -h / --help / -help 时显示中文帮助和常用指令集
function ffmpeg
    for arg in $argv
        if string match -qr '^(-h|--h|-help|--help|-\?)$' -- $arg
            command cat ~/.config/fish/zhhelp/ffmpeg.txt 2>/dev/null; or echo "暂无中文帮助: ffmpeg"
            return 0
        end
    end
    command ffmpeg $argv
end
