function yt-dlp
    for arg in $argv
        if string match -qr '^(-h|--h|-help|--help|-\?)$' -- $arg
            command cat ~/.config/fish/zhhelp/yt-dlp.txt; or echo "暂无中文帮助: yt-dlp"
            return 0
        end
    end
    command yt-dlp $argv
end
