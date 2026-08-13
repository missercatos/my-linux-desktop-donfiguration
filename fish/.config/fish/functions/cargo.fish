function cargo
    for arg in $argv
        if string match -qr '^(-h|--h|-help|--help|-\?)$' -- $arg
            command cat ~/.config/fish/zhhelp/cargo.txt; or echo "暂无中文帮助: cargo"
            return 0
        end
    end
    command cargo $argv
end
