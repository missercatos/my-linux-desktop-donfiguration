if status is-interactive
    # Commands to run in interactive sessions can go here
end
set fish_greeting ""
fish_vi_key_bindings
function fish_mode_prompt; end

# ===== Clash 终端自动代理 =====
# 仅交互终端生效: 检测到 clash 端口(7890)开启 -> 自动启用代理加速
# 未开启 -> 不设代理, 走默认网络 (不影响 Chrome/Firefox 等 GUI)
if status is-interactive
    function __proxy_apply -a host port
        set -gx http_proxy http://$host:$port
        set -gx https_proxy http://$host:$port
        set -gx all_proxy socks5://$host:$port
        set -gx HTTP_PROXY http://$host:$port
        set -gx HTTPS_PROXY http://$host:$port
        set -gx ALL_PROXY socks5://$host:$port
        set -gx no_proxy localhost,127.0.0.1,::1
    end

    # 自动检测(仅在未手动指定时生效)
    function __proxy_auto
        if set -q __proxy_manual; return; end
        if command -v ss >/dev/null 2>&1; and ss -tln 2>/dev/null | grep -q ':7890 '
            __proxy_apply 127.0.0.1 7890
        else
            set -e http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY no_proxy 2>/dev/null
        end
    end

    # 每次提示符前刷新(使开关即时生效)
    function __proxy_auto_hook --on-event fish_prompt
        __proxy_auto
    end
    # 初始执行一次
    __proxy_auto

    # 手动指定当前终端走某端口: proxyon [端口]; 之后自动检测不再覆盖
    function proxyon
        set -l p $argv[1]
        if test -z "$p"; set p 7890; end
        set -g __proxy_manual 1
        __proxy_apply 127.0.0.1 $p
        echo "代理已启用 -> 127.0.0.1:$p (仅当前终端, 手动锁定)"
    end
    function proxyoff
        set -e __proxy_manual 2>/dev/null
        set -e http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY no_proxy 2>/dev/null
        echo "代理已关闭, 走默认网络"
    end
    function proxycheck
        if set -q __proxy_manual
            echo "代理模式: 手动锁定 http_proxy=$http_proxy"
        else if command -v ss >/dev/null 2>&1; and ss -tln 2>/dev/null | grep -q ':7890 '
            echo "代理模式: 自动 (clash 运行中)"
        else
            echo "代理模式: 默认网络 (clash 未运行)"
        end
    end
end

set -gx MANPATH /usr/share/man/zh_CN:
set -gx LANGUAGE zh_CN.UTF-8
set -p PATH ~/hackingtools/bin ~/.local/bin
set -gx STARSHIP_CONFIG ~/.config/tactical/starship.toml
# Generate starship config from DMS theme
~/.local/bin/generate-starship-dms >/dev/null 2>&1
starship init fish | source
zoxide init fish --cmd cd | source
# 111
function y
	set tmp (mktemp -t "yazi-cwd.XXXXXX")
	yazi $argv --cwd-file="$tmp"
	if read -z cwd < "$tmp"; and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
		builtin cd -- "$cwd"
	end
	rm -f -- "$tmp"
end

function cat 
	command bat $argv
end
function ls
	command eza --icons $argv
end

function lt
	command eza --icons --tree $argv
end
# grub
abbr grub 'LANGUAGE=en_US.UTF-8 LANG=en_US.UTF-8 sudo grub-mkconfig -o /boot/grub/grub.cfg'
# 小黄鸭补帧 需要steam安装正版小黄鸭
abbr lsfg 'LSFG_PROCESS="miyu"'
# fa运行fastfetch
abbr fa fastfetch
abbr reboot 'systemctl reboot'
function sl 
	command sl | lolcat	
end
function 滚
	sysup 
end
function raw
	command ~/.local/bin/random-anime-wallpaper-dms $argv
end

function 安装
	command yay -S $argv
end

function 卸载
	command yay -Rns $argv
end 


