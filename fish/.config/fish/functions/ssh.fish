function ssh
    for arg in $argv
        if string match -qr '^(-h|--h|-help|--help|-\?)$' -- $arg
            command cat ~/.config/fish/zhhelp/ssh.txt; or echo "暂无中文帮助: ssh"
            return 0
        end
    end
    command ssh $argv
end
