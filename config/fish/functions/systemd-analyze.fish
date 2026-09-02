function systemd-analyze
    for arg in $argv
        if string match -qr '^(-h|--h|-help|--help|-\?)$' -- $arg
            command cat ~/.config/fish/zhhelp/systemd-analyze.txt; or echo "暂无中文帮助: systemd-analyze"
            return 0
        end
    end
    command systemd-analyze $argv
end
