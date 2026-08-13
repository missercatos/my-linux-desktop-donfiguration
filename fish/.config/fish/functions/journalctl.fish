function journalctl
    for arg in $argv
        if string match -qr '^(-h|--h|-help|--help|-\?)$' -- $arg
            command cat ~/.config/fish/zhhelp/journalctl.txt; or echo "暂无中文帮助: journalctl"
            return 0
        end
    end
    command journalctl $argv
end
