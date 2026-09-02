function pacman
    for arg in $argv
        if string match -qr '^(-h|--h|-help|--help|-\?)$' -- $arg
            command cat ~/.config/fish/zhhelp/pacman.txt; or echo "暂无中文帮助: pacman"
            return 0
        end
    end
    command pacman $argv
end
