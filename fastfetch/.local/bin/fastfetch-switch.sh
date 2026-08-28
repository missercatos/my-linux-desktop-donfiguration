#!/usr/bin/env bash
# fastfetch-switch.sh - 根据终端类型选择fastfetch配置
# 用法: fastfetch-switch.sh [green|dms]

set -euo pipefail

CONFIG_DIR="$HOME/.config/fastfetch"
GREEN_CONFIG="$CONFIG_DIR/config-green.jsonc"
DMS_CONFIG="$CONFIG_DIR/config.jsonc"

# 检测终端类型
detect_terminal() {
    if [[ -n "${ALACRITTY_SOCKET:-}" ]] || [[ "${TERM_PROGRAM:-}" == "Alacritty" ]]; then
        echo "alacritty"
    elif [[ -n "${FOOT_SOCKET:-}" ]] || [[ "${TERM:-}" == "foot" ]] || [[ "${TERM:-}" == "foot-extra" ]]; then
        echo "foot"
    elif [[ -z "${DISPLAY:-}" ]] && [[ -z "${WAYLAND_DISPLAY:-}" ]] && [[ "${TERM:-}" != "xterm-256color" ]]; then
        echo "tty"
    else
        echo "unknown"
    fi
}

# 选择配置
select_config() {
    local terminal=$(detect_terminal)
    local mode="${1:-auto}"
    
    if [[ "$mode" == "green" ]]; then
        echo "$GREEN_CONFIG"
    elif [[ "$mode" == "dms" ]]; then
        echo "$DMS_CONFIG"
    else
        # 自动模式：根据终端类型选择
        case "$terminal" in
            alacritty|foot|tty)
                echo "$GREEN_CONFIG"
                ;;
            *)
                echo "$DMS_CONFIG"
                ;;
        esac
    fi
}

# 主函数
main() {
    local config=$(select_config "${1:-auto}")
    
    if [[ ! -f "$config" ]]; then
        echo "错误: 配置文件不存在: $config" >&2
        exit 1
    fi
    
    # 执行fastfetch
    fastfetch --config "$config"
}

main "$@"
