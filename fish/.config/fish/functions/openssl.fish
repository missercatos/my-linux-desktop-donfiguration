function openssl
    for arg in $argv
        if string match -qr '^(-h|--h|-help|--help|-\?)$' -- $arg
            command cat ~/.config/fish/zhhelp/openssl.txt; or echo "暂无中文帮助: openssl"
            return 0
        end
    end
    command openssl $argv
end
