function ssh-copy-id
    for arg in $argv
        if string match -qr '^(-h|--h|-help|--help|-\?)$' -- $arg
            command cat ~/.config/fish/zhhelp/ssh-copy-id.txt; or echo "暂无中文帮助: ssh-copy-id"
            return 0
        end
    end
    command ssh-copy-id $argv
end
