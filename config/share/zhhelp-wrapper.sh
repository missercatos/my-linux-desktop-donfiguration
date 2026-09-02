# ~/.local/share/zhhelp-wrapper.sh
# 中文帮助包装函数 - 供 bash/zsh 加载
# 用法: 在 .bashrc / .zshrc 中添加: source ~/.local/share/zhhelp-wrapper.sh

_zhhelp_dir="${HOME}/.local/share/zhhelp"

# 生成包装函数的通用函数
_zhhelp_wrap() {
    local cmd="$1"
    eval "
function $cmd() {
    local arg
    for arg in \"\$@\"; do
        case \"\$arg\" in
            -h|--h|-help|--help|-\?)
                if [[ -f \"${_zhhelp_dir}/${cmd}.txt\" ]]; then
                    cat \"${_zhhelp_dir}/${cmd}.txt\"
                else
                    echo \"暂无中文帮助: ${cmd}\"
                fi
                return 0
                ;;
        esac
    done
    command $cmd \"\$@\"
}
"
}

# ── 网络工具 ──
_zhhelp_wrap curl
_zhhelp_wrap wget
_zhhelp_wrap scp
_zhhelp_wrap sftp
_zhhelp_wrap ssh
_zhhelp_wrap rsync
_zhhelp_wrap dig
_zhhelp_wrap ip
_zhhelp_wrap ss
_zhhelp_wrap ping

# ── 媒体工具 ──
_zhhelp_wrap ffmpeg
_zhhelp_wrap ffprobe
_zhhelp_wrap ffplay
_zhhelp_wrap mpv
_zhhelp_wrap jp2a
_zhhelp_wrap chafa
_zhhelp_wrap convert
_zhhelp_wrap magick

# ── 文件操作 ──
_zhhelp_wrap tar
_zhhelp_wrap gzip
_zhhelp_wrap bzip2
_zhhelp_wrap xz
_zhhelp_wrap zip
_zhhelp_wrap unzip
_zhhelp_wrap cp
_zhhelp_wrap mv
_zhhelp_wrap rm
_zhhelp_wrap ln
_zhhelp_wrap mkdir

# ── 开发工具 ──
_zhhelp_wrap git
_zhhelp_wrap gh
_zhhelp_wrap docker
_zhhelp_wrap cargo
_zhhelp_wrap node
_zhhelp_wrap npm
_zhhelp_wrap nvim
_zhhelp_wrap vim

# ── 包管理 ──
_zhhelp_wrap pacman
_zhhelp_wrap yay
_zhhelp_wrap paru

# ── 系统工具 ──
_zhhelp_wrap systemctl
_zhhelp_wrap journalctl
_zhhelp_wrap tmux
_zhhelp_wrap fzf
_zhhelp_wrap jq
_zhhelp_wrap rg
_zhhelp_wrap sqlite3

# ── 压缩/归档 ──
_zhhelp_wrap 7z
_zhhelp_wrap zoxide

# ── 文本处理 ──
_zhhelp_wrap awk
_zhhelp_wrap sed
_zhhelp_wrap grep
_zhhelp_wrap find

# ── 安全工具 ──
_zhhelp_wrap openssl
_zhhelp_wrap gdb
_zhhelp_wrap r2
_zhhelp_wrap radare2
_zhhelp_wrap rizin
_zhhelp_wrap ghidra
_zhhelp_wrap jadx
_zhhelp_wrap binwalk
_zhhelp_wrap strings
_zhhelp_wrap objdump
_zhhelp_wrap readelf
_zhhelp_wrap ROPgadget
_zhhelp_wrap rabin2
_zhhelp_wrap rz-bin
_zhhelp_wrap pwn
_zhhelp_wrap sqlmap
_zhhelp_wrap wireshark
_zhhelp_wrap tshark
_zhhelp_wrap socat
_zhhelp_wrap smbclient
_zhhelp_wrap rpcclient
_zhhelp_wrap strace
_zhhelp_wrap ltrace
_zhhelp_wrap file
_zhhelp_wrap base64

# ── 终端工具 ──
_zhhelp_wrap btop
_zhhelp_wrap eza
_zhhelp_wrap bat
_zhhelp_wrap tree
_zhhelp_wrap fd
_zhhelp_wrap identify

# ── 编程开发 ──
_zhhelp_wrap docker-compose
_zhhelp_wrap rustc
_zhhelp_wrap gcc
_zhhelp_wrap g++
_zhhelp_wrap cmake
_zhhelp_wrap python
_zhhelp_wrap python3

# ── 网络工具 ──
_zhhelp_wrap traceroute
_zhhelp_wrap arping
_zhhelp_wrap aria2c

# ── AI工具 ──
_zhhelp_wrap kd
_zhhelp_wrap dsh

# ── 其他 ──
_zhhelp_wrap make
_zhhelp_wrap du
_zhhelp_wrap df
_zhhelp_wrap ps
_zhhelp_wrap top
_zhhelp_wrap lsof
_zhhelp_wrap nmcli
_zhhelp_wrap pactl
_zhhelp_wrap wpctl
_zhhelp_wrap wl-copy
_zhhelp_wrap grim
_zhhelp_wrap slurp
_zhhelp_wrap watch
_zhhelp_wrap journalctl
_zhhelp_wrap systemd-analyze

unset -f _zhhelp_wrap
