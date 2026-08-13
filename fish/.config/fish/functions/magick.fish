function magick
    for arg in $argv
        if string match -qr '^(-h|--h|-help|--help|-\?)$' -- $arg
            command cat ~/.config/fish/zhhelp/magick.txt; or echo "暂无中文帮助: magick"
            return 0
        end
    end
    command magick $argv
end
