#!/usr/bin/env bash

# 当前脚本版本号
VERSION='beta 5'

# 各变量默认值
GH_PROXY='https://ghproxy.com'
TEMP_DIR='/tmp/sing-box'
WORK_DIR='/etc/sing-box'
START_PORT_DEFAULT='8881'
MIN_PORT=1000
MAX_PORT=65525
TLS_SERVER=addons.mozilla.org
CDN_DEFAULT=www.who.int
PROTOCAL_LIST=("shadowTLS" "reality" "hysteria2" "tuic" "shadowsocks" "trojan" "vmess + ws" "vless + ws + tls")
CONSECUTIVE_PORTS=${#PROTOCAL_LIST[@]}
CDN_DOMAIN=("www.who.int" "cdn.anycast.eu.org" "443.cf.bestl.de" "cfip.gay")

trap "rm -rf $TEMP_DIR >/dev/null 2>&1 ; echo -e '\n' ;exit 1" INT QUIT TERM EXIT

mkdir -p $TEMP_DIR

E[0]="Language:\n 1. English (default) \n 2. 简体中文"
C[0]="${E[0]}"
E[1]="1. Add the option to use Warp for returning to China; 2. Add a number of quality cdn's that are collected online"
C[1]="1. 增加使用 Warp 回国选项; 2. 增加线上收录的若干优质 cdn"
E[2]="This project is designed to add sing-box support for multiple protocols to VPS, details: [https://github.com/fscarmen/sing-box]\n Script Features:\n\t • Deploy multiple protocols with one click, there is always one for you!\n\t • Custom ports for nat machine with limited open ports.\n\t • Built-in warp chained proxy to unlock chatGPT.\n\t • No domain name is required.\n\t • Support system: Ubuntu, Debian, CentOS, Alpine and Arch Linux 3.\n\t • Support architecture: AMD,ARM and s390x\n"
C[2]="本项目专为 VPS 添加 sing-box 支持的多种协议, 详细说明: [https://github.com/fscarmen/sing-box]\n 脚本特点:\n\t • 一键部署多协议，总有一款适合你\n\t • 自定义端口，适合有限开放端口的 nat 小鸡\n\t • 内置 warp 链式代理解锁 chatGPT\n\t • 不需要域名\n\t • 智能判断操作系统: Ubuntu 、Debian 、CentOS 、Alpine 和 Arch Linux,请务必选择 LTS 系统\n\t • 支持硬件结构类型: AMD 和 ARM\n"
E[3]="Input errors up to 5 times.The script is aborted."
C[3]="输入错误达5次,脚本退出"
E[4]="UUID should be 36 characters, please re-enter \(\${UUID_ERROR_TIME} times remaining\):"
C[4]="UUID 应为36位字符,请重新输入 \(剩余\${UUID_ERROR_TIME}次\):"
E[5]="The script supports Debian, Ubuntu, CentOS, Alpine or Arch systems only. Feedback: [https://github.com/fscarmen/sing-box/issues]"
C[5]="本脚本只支持 Debian、Ubuntu、CentOS、Alpine 或 Arch 系统,问题反馈:[https://github.com/fscarmen/sing-box/issues]"
E[6]="Curren operating system is \$SYS.\\\n The system lower than \$SYSTEM \${MAJOR[int]} is not supported. Feedback: [https://github.com/fscarmen/sing-box/issues]"
C[6]="当前操作是 \$SYS\\\n 不支持 \$SYSTEM \${MAJOR[int]} 以下系统,问题反馈:[https://github.com/fscarmen/sing-box/issues]"
E[7]="Install dependence-list:"
C[7]="安装依赖列表:"
E[8]="All dependencies already exist and do not need to be installed additionally."
C[8]="所有依赖已存在，不需要额外安装"
E[9]="To upgrade, press [y]. No upgrade by default:"
C[9]="升级请按 [y]，默认不升级:"
E[10]="Please enter VPS IP \(Default is: \${SERVER_IP_DEFAULT}\):"
C[10]="请输入 VPS IP \(默认为: \${SERVER_IP_DEFAULT}\):"
E[11]="Please enter the starting port number. Must be \${MIN_PORT} - \${MAX_PORT}, consecutive \${NUM} free ports are required \(Default is: \${START_PORT_DEFAULT}\):"
C[11]="请输入开始的端口号，必须是 \${MIN_PORT} - \${MAX_PORT}，需要连续\${NUM}个空闲的端口 \(默认为: \${START_PORT_DEFAULT}\):"
E[12]="Please enter UUID \(Default is \${UUID_DEFAULT}\):"
C[12]="请输入 UUID \(默认为 \${UUID_DEFAULT}\):"
E[13]="Please enter the node name. \(Default is \${NODE_NAME_DEFAULT}\):"
C[13]="请输入节点名称 \(默认为 \${NODE_NAME_DEFAULT}\):"
E[14]="Node name only allow uppercase and lowercase letters and numeric characters, please re-enter \(\${a} times remaining\):"
C[14]="节点名称只允许英文大小写及数字字符，请重新输入 \(剩余\${a}次\):"
E[15]="Sing-box script has not been installed yet."
C[15]="Sing-box 脚本还没有安装"
E[16]="Sing-box is completely uninstalled."
C[16]="Sing-box 已彻底卸载"
E[17]="Version"
C[17]="脚本版本"
E[18]="New features"
C[18]="功能新增"
E[19]="System infomation"
C[19]="系统信息"
E[20]="Operating System"
C[20]="当前操作系统"
E[21]="Kernel"
C[21]="内核"
E[22]="Architecture"
C[22]="处理器架构"
E[23]="Virtualization"
C[23]="虚拟化"
E[24]="Choose:"
C[24]="请选择:"
E[25]="Curren architecture \$(uname -m) is not supported. Feedback: [https://github.com/fscarmen/sing-box/issues]"
C[25]="当前架构 \$(uname -m) 暂不支持,问题反馈:[https://github.com/fscarmen/sing-box/issues]"
E[26]="Not install"
C[26]="未安装"
E[27]="close"
C[27]="关闭"
E[28]="open"
C[28]="开启"
E[29]="View links"
C[29]="查看节点信息"
E[30]="Change listen ports"
C[30]="更换监听端口"
E[31]="Sync Sing-box to the latest version"
C[31]="同步 Sing-box 至最新版本"
E[32]="Upgrade kernel, turn on BBR, change Linux system"
C[32]="升级内核、安装BBR、DD脚本"
E[33]="Uninstall"
C[33]="卸载"
E[34]="Install script"
C[34]="安装脚本"
E[35]="Exit"
C[35]="退出"
E[36]="Please enter the correct number"
C[36]="请输入正确数字"
E[37]="successful"
C[37]="成功"
E[38]="failed"
C[38]="失败"
E[39]="Sing-box is not installed."
C[39]="Sing-box 未安装"
E[40]="Sing-box local verion: \$LOCAL.\\\t The newest verion: \$ONLINE"
C[40]="Sing-box 本地版本: \$LOCAL.\\\t 最新版本: \$ONLINE"
E[41]="No upgrade required."
C[41]="不需要升级"
E[42]="Downloading the latest version Sing-box failed, script exits. Feedback:[https://github.com/fscarmen/sing-box/issues]"
C[42]="下载最新版本 Sing-box 失败，脚本退出，问题反馈:[https://github.com/fscarmen/sing-box/issues]"
E[43]="The script must be run as root, you can enter sudo -i and then download and run again. Feedback:[https://github.com/fscarmen/sing-box/issues]"
C[43]="必须以root方式运行脚本，可以输入 sudo -i 后重新下载运行，问题反馈:[https://github.com/fscarmen/sing-box/issues]"
E[44]="Ports are in used:  \${IN_USED[*]}"
C[44]="正在使用中的端口: \${IN_USED[*]}"
E[45]="Ports used: \${NOW_START_PORT} - \$((NOW_START_PORT+NOW_CONSECUTIVE_PORTS-1))"
C[45]="使用端口: \${NOW_START_PORT} - \$((NOW_START_PORT+NOW_CONSECUTIVE_PORTS-1))"
E[46]="Warp / warp-go was detected to be running. Please close and run this script again."
C[46]="检测到 warp / warp-go 正在运行，请关闭后再次运行本脚本"
E[47]="No server ip, script exits. Feedback:[https://github.com/fscarmen/sing-box/issues]"
C[47]="没有 server ip，脚本退出，问题反馈:[https://github.com/fscarmen/sing-box/issues]"
E[48]="ShadowTLS - Copy the above two Neko links and manually set up the chained proxies in order. Tutorial: https://github.com/fscarmen/sing-box/blob/main/README.md#sekobox-%E8%AE%BE%E7%BD%AE-shadowtls-%E6%96%B9%E6%B3%95"
C[48]="ShadowTLS - 复制上面两条 Neko links 进去，并按顺序手动设置链式代理，详细教程: https://github.com/fscarmen/sing-box/blob/main/README.md#sekobox-%E8%AE%BE%E7%BD%AE-shadowtls-%E6%96%B9%E6%B3%95"
E[49]="Select more protocols to install (e.g. hgbd):\n a. all (default)"
C[49]="多选需要安装协议(比如 hgbd):\n a. all (默认)"
E[50]="Please enter the \$TYPE domain name:"
C[50]="请输入 \$TYPE 域名:"
E[51]="Please choose or custom a cdn, http support is required:"
C[51]="请选择或输入 cdn，要求支持 http:"
E[52]="Please set the ip \[\${WS_SERVER_IP}] to domain \[\${TYPE_HOST_DOMAIN}], and set the origin rule to \[\${TYPE_PORT_WS}] in Cloudflare."
C[52]="请在 Cloudflare 绑定 \[\${WS_SERVER_IP}] 的域名为 \[\${TYPE_HOST_DOMAIN}], 并设置 origin rule 为 \[\${TYPE_PORT_WS}]"
E[53]="Please select or enter the preferred domain, the default is \${CDN_DOMAIN[0]}:"
C[53]="请选择或者填入优选域名，默认为 \${CDN_DOMAIN[0]}:"
E[54]="The contents of the \$V2RAYN_PROTOCAL configuration file need to be updated for the \$V2RAYN_KERNEL kernel."
C[54]="\$V2RAYN_PROTOCAL 配置文件内容，需要更新 \$V2RAYN_KERNEL 内核"
E[55]="Please set inSecure in tls to true."
C[55]="请把 tls 里的 inSecure 设置为 true"
E[56]="Do you use warp to access mainland websites?\n Pros: Increase security by using Cloudflare on 104.28.x.x to access domestic websites.\n Cons: Slows down access."
C[56]="是否使用 warp 访问大陆网站功能?\n 优点: 使用 104.28.x.x 的 Cloudflare 访问国内网站，增加安全性\n 缺点: 减慢访问速度"
E[57]="Use warp to access mainland websites"
C[57]="warp 回国"
E[58]="Install ArgoX scripts (argo + xray) [https://github.com/fscarmen/argox]"
C[58]="安装 ArgoX 脚本 (argo + xray) [https://github.com/fscarmen/argox]"
E[59]="Default: [Disabled]. Press [y] if you need it:"
C[59]="默认为: [不需要]，如需开启请按 [y]:"
E[60]="The order of the selected protocols and ports is as follows:"
C[60]="选择的协议及端口次序如下:"
E[61]="(DNS your own domain in Cloudflare is required.)"
C[61]="(必须在 Cloudflare 解析自有域名)"

# 自定义字体彩色，read 函数
warning() { echo -e "\033[31m\033[01m$*\033[0m"; }  # 红色
error() { echo -e "\033[31m\033[01m$*\033[0m" && exit 1; } # 红色
info() { echo -e "\033[32m\033[01m$*\033[0m"; }   # 绿色
hint() { echo -e "\033[33m\033[01m$*\033[0m"; }   # 黄色
reading() { read -rp "$(info "$1")" "$2"; }
text() { eval echo "\${${L}[$*]}"; }
text_eval() { eval echo "\$(eval echo "\${${L}[$*]}")"; }

# 自定义友道或谷歌翻译函数
translate() {
  [ -n "$@" ] && EN="$@"
  ZH=$(wget -qO- -t1T2 "https://translate.google.com/translate_a/t?client=any_client_id_works&sl=en&tl=zh&q=${EN//[[:space:]]/%20}")
  [[ "$ZH" =~ ^\[\".+\"\]$ ]] && cut -d \" -f2 <<< "$ZH"
}

# 选择中英语言
select_language() {
  if [ -z "$L" ]; then
    case $(cat $WORK_DIR/language 2>&1) in
      E ) L=E ;;
      C ) L=C ;;
      * ) [ -z "$L" ] && L=E && hint "\n $(text 0) \n" && reading " $(text 24) " LANGUAGE
      [ "$LANGUAGE" = 2 ] && L=C ;;
    esac
  fi
}

# 字母与数字的 ASCII 码值转换
asc(){
  if [[ "$1" = [a-z] ]]; then
    [ "$2" = '++' ] && printf "\\$(printf '%03o' "$[ $(printf "%d" "'$1'") + 1 ]")" || printf "%d" "'$1'"
  else
    [[ "$1" =~ ^[0-9]+$ ]] && printf "\\$(printf '%03o' "$1")"
  fi
}

check_root() {
  [ "$(id -u)" != 0 ] && error "\n $(text 43) \n"
}

check_arch() {
  # 判断处理器架构
  case $(uname -m) in
    aarch64|arm64 ) ARCH=arm64 ;;
    x86_64|amd64 ) ARCH=amd64 ;;
    armv7l ) ARCH=armv7 ;;
    * ) error " $(text_eval 25) "
  esac
}

# 查安装及运行状态；状态码: 26 未安装， 27 已安装未运行， 28 运行中
check_install() {
  STATUS=$(text 26) && [ -s /etc/systemd/system/sing-box.service ] && STATUS=$(text 27) && [ "$(systemctl is-active sing-box)" = 'active' ] && STATUS=$(text 28)
  if [[ $STATUS = "$(text 26)" ]] && [ ! -s $WORK_DIR/sing-box ]; then
    {
    local ONLINE=$(wget -qO- "https://api.github.com/repos/SagerNet/sing-box/releases/latest" | grep "tag_name" | sed "s@.*\"v\(.*\)\",@\1@g")
    ONLINE=${ONLINE:-'1.5.2'}
    wget -qO $TEMP_DIR/sing-box.tar.gz $GH_PROXY/https://github.com/SagerNet/sing-box/releases/download/v$ONLINE/sing-box-$ONLINE-linux-$ARCH.tar.gz >/dev/null 2>&1
    tar xzf $TEMP_DIR/sing-box.tar.gz -C $TEMP_DIR sing-box-$ONLINE-linux-$ARCH/sing-box >/dev/null 2>&1
    mv $TEMP_DIR/sing-box-$ONLINE-linux-$ARCH/sing-box $TEMP_DIR >/dev/null 2>&1
    }&
  fi
}

# 判断虚拟化
check_system_info() {
  VIRT=$(systemd-detect-virt 2>/dev/null | tr 'A-Z' 'a-z')
  [ -n "$VIRT" ] || VIRT=$(hostnamectl 2>/dev/null | tr 'A-Z' 'a-z' | grep virtualization | sed "s/.*://g")

  [ -s /etc/os-release ] && SYS="$(grep -i pretty_name /etc/os-release | cut -d \" -f2)"
  [[ -z "$SYS" && $(type -p hostnamectl) ]] && SYS="$(hostnamectl | grep -i system | cut -d : -f2)"
  [[ -z "$SYS" && $(type -p lsb_release) ]] && SYS="$(lsb_release -sd)"
  [[ -z "$SYS" && -s /etc/lsb-release ]] && SYS="$(grep -i description /etc/lsb-release | cut -d \" -f2)"
  [[ -z "$SYS" && -s /etc/redhat-release ]] && SYS="$(grep . /etc/redhat-release)"
  [[ -z "$SYS" && -s /etc/issue ]] && SYS="$(grep . /etc/issue | cut -d '\' -f1 | sed '/^[ ]*$/d')"

  REGEX=("debian" "ubuntu" "centos|red hat|kernel|oracle linux|alma|rocky" "amazon linux" "arch linux" "alpine")
  RELEASE=("Debian" "Ubuntu" "CentOS" "CentOS" "Arch" "Alpine")
  EXCLUDE=("bookworm")
  MAJOR=("9" "16" "7" "7" "" "")
  PACKAGE_UPDATE=("apt -y update" "apt -y update" "yum -y update" "yum -y update" "pacman -Sy" "apk update -f")
  PACKAGE_INSTALL=("apt -y install" "apt -y install" "yum -y install" "yum -y install" "pacman -S --noconfirm" "apk add --no-cache")
  PACKAGE_UNINSTALL=("apt -y autoremove" "apt -y autoremove" "yum -y autoremove" "yum -y autoremove" "pacman -Rcnsu --noconfirm" "apk del -f")

  for ((int=0; int<${#REGEX[@]}; int++)); do
    [[ $(tr 'A-Z' 'a-z' <<< "$SYS") =~ ${REGEX[int]} ]] && SYSTEM="${RELEASE[int]}" && break
  done
  [ -z "$SYSTEM" ] && error " $(text 5) "

  # 先排除 EXCLUDE 里包括的特定系统，其他系统需要作大发行版本的比较
  for ex in "${EXCLUDE[@]}"; do [[ ! $(tr 'A-Z' 'a-z' <<< "$SYS")  =~ $ex ]]; done &&
  [[ "$(echo "$SYS" | sed "s/[^0-9.]//g" | cut -d. -f1)" -lt "${MAJOR[int]}" ]] && error " $(text_eval 6) "
}

# 检测 IPv4 IPv6 信息
check_system_ip() {
  IP4=$(wget -4 -qO- --no-check-certificate --user-agent=Mozilla --tries=2 --timeout=1 http://ip-api.com/json/) &&
  WAN4=$(expr "$IP4" : '.*query\":[ ]*\"\([^"]*\).*') &&
  COUNTRY4=$(expr "$IP4" : '.*country\":[ ]*\"\([^"]*\).*') &&
  ASNORG4=$(expr "$IP4" : '.*isp\":[ ]*\"\([^"]*\).*') &&
  [[ "$L" = C && -n "$COUNTRY4" ]] && COUNTRY4=$(translate "$COUNTRY4")

  IP6=$(wget -6 -qO- --no-check-certificate --user-agent=Mozilla --tries=2 --timeout=1 https://api.ip.sb/geoip) &&
  WAN6=$(expr "$IP6" : '.*ip\":[ ]*\"\([^"]*\).*') &&
  COUNTRY6=$(expr "$IP6" : '.*country\":[ ]*\"\([^"]*\).*') &&
  ASNORG6=$(expr "$IP6" : '.*isp\":[ ]*\"\([^"]*\).*') &&
  [[ "$L" = C && -n "$COUNTRY6" ]] && COUNTRY6=$(translate "$COUNTRY6")
}

# 输入起始 port 函数
enter_start_port() {
  local NUM=$1
  local PORT_ERROR_TIME=6
  while true; do
    [ "$PORT_ERROR_TIME" -lt 6 ] && unset IN_USED START_PORT
    (( PORT_ERROR_TIME-- )) || true
    if [ "$PORT_ERROR_TIME" = 0 ]; then
      error "\n $(text 3) \n"
    else
      [ -z "$START_PORT" ] && reading "\n $(text_eval 11) " START_PORT
    fi
    START_PORT=${START_PORT:-"$START_PORT_DEFAULT"}
    if [[ "$START_PORT" =~ ^[1-9][0-9]{3,4}$ && "$START_PORT" -ge "$MIN_PORT" && "$START_PORT" -le "$MAX_PORT" ]]; then
      for port in $(eval echo {$START_PORT..$[START_PORT+NUM-1]}); do
        lsof -i:$port >/dev/null 2>&1 && IN_USED+=("$port")
      done
      [ "${#IN_USED[*]}" -eq 0 ] && break || warning "\n $(text_eval 44) \n"
    fi
  done
}

# 定义 Sing-box 变量
sing-box_variable() {
  if grep -qi 'cloudflare' <<< "$ASNORG4$ASNORG6"; then
    error "\n $(text 46) \n"
  elif [ -n "$WAN4" ]; then
    SERVER_IP_DEFAULT=$WAN4
    WARP_ENDPOINT=162.159.193.10
    DOMAIN_STRATEG=prefer_ipv4
  elif [ -n "$WAN6" ]; then
    SERVER_IP_DEFAULT=$WAN6
    WARP_ENDPOINT=2606:4700:d0::a29f:c101
    DOMAIN_STRATEG=prefer_ipv6
  fi

  # 选择安装的协议，由于选项 a 为全部协议，所以选项数不是从 a 开始，而是从 b 开始，处理输入：把大写全部变为小写，把不符合的选项去掉，把重复的选项合并
  MAX_CHOOSE_PROTOCALS=$(asc $[CONSECUTIVE_PORTS+96+1])
  if [ -z "$CHOOSE_PROTOCALS" ]; then
    hint "\n $(text 49) "
    for ((e=0; e<${#PROTOCAL_LIST[@]}; e++)); do
      [[ "$e" =~ '6'|'7' ]] && hint " $(asc $[e+98]). ${PROTOCAL_LIST[e]} $(text 61) " || hint " $(asc $[e+98]). ${PROTOCAL_LIST[e]} "
    done
    reading "\n $(text 24) " CHOOSE_PROTOCALS
  fi

  # 对选择协议的输入处理逻辑：先把所有的大写转为小写，并把所有没有去选项剔除掉，最后按输入的次序排序。如果选项为 a(all) 和其他选项并存，将会忽略 a，如 abc 则会处理为 bc
  CHOOSE_PROTOCALS=$(tr '[:upper:]' '[:lower:]' <<< "$CHOOSE_PROTOCALS")
  [[ ! "$CHOOSE_PROTOCALS" =~ [b-$MAX_CHOOSE_PROTOCALS] ]] && INSTALL_PROTOCALS=($(eval echo {b..$MAX_CHOOSE_PROTOCALS})) || INSTALL_PROTOCALS=($(grep -o . <<< "$CHOOSE_PROTOCALS" | sed "/[^b-$MAX_CHOOSE_PROTOCALS]/d" | awk '!seen[$0]++'))

  # 显示选择协议及其次序，输入开始端口号
  if [ -z "$START_PORT" ]; then
    hint "\n $(text 60) "
    for ((d=0; d<${#INSTALL_PROTOCALS[@]}; d++)); do
      hint " $[d+1]. ${PROTOCAL_LIST[$(($(asc ${INSTALL_PROTOCALS[d]}) - 98))]} "
    done
    enter_start_port ${#INSTALL_PROTOCALS[@]}
  fi

  # 输入服务器 IP,默认为检测到的服务器 IP，如果全部为空，则提示并退出脚本
  [ -z "$SERVER_IP" ] && reading "\n $(text_eval 10) " SERVER_IP
  SERVER_IP=${SERVER_IP:-"$SERVER_IP_DEFAULT"} && WS_SERVER_IP=$SERVER_IP
  [ -z "$SERVER_IP" ] && error " $(text 47) "

  # 如选择有 h. vmess + ws 或 i. vless + ws 时，先检测是否有支持的 http 端口可用，如有则要求输入域名和 cdn
  if [[ "${INSTALL_PROTOCALS[@]}" =~ 'h' ]]; then
    local DOMAIN_ERROR_TIME=5
    until [ -n "$VMESS_HOST_DOMAIN" ]; do
      (( DOMAIN_ERROR_TIME-- )) || true
      [ "$DOMAIN_ERROR_TIME" != 0 ] && TYPE=VMESS && reading "\n $(text_eval 50) " VMESS_HOST_DOMAIN || error "\n $(text 3) \n"
    done
  fi

  if [[ "${INSTALL_PROTOCALS[@]}" =~ 'i' ]]; then
    local DOMAIN_ERROR_TIME=5
    until [ -n "$VLESS_HOST_DOMAIN" ]; do
      (( DOMAIN_ERROR_TIME-- )) || true
      [ "$DOMAIN_ERROR_TIME" != 0 ] && TYPE=VLESS && reading "\n $(text_eval 50) " VLESS_HOST_DOMAIN || error "\n $(text 3) \n"
    done
  fi

  # 提供网上热心网友的anycast域名
  if [ -n "$VMESS_HOST_DOMAIN$VLESS_HOST_DOMAIN" ]; then
    echo ""
    for ((c=0; c<${#CDN_DOMAIN[@]}; c++)); do hint " $[c+1]. ${CDN_DOMAIN[c]} "; done

    reading "\n $(text_eval 53) " CUSTOM_CDN
    case "$CUSTOM_CDN" in
      [1-${#CDN_DOMAIN[@]}] )
        CDN="${CDN_DOMAIN[$((CUSTOM_CDN-1))]}"
      ;;
      ?????* )
        CDN="$CUSTOM_CDN"
      ;;
      * )
        CDN="${CDN_DOMAIN[0]}"
    esac
  fi

  # 是否开启禁止归国模式，默认不开启
  [ -z "$RETURN" ] && hint "\n $(text 56) " && reading "\n $(text 59) " RETURN
  RETURN=$(tr 'A-Z' 'a-z' <<< "$RETURN")

  wait

  # 输入 UUID ，错误超过 5 次将会退出
  UUID_DEFAULT=$($TEMP_DIR/sing-box generate uuid)
  [ -z "$UUID" ] && reading "\n $(text_eval 12) " UUID
  local UUID_ERROR_TIME=5
  until [[ -z "$UUID" || "$UUID" =~ ^[A-F0-9a-f]{8}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{12}$ ]]; do
    (( UUID_ERROR_TIME-- )) || true
    [ "$UUID_ERROR_TIME" = 0 ] && error "\n $(text 3) \n" || reading "\n $(text_eval 4) \n" UUID
  done
  UUID=${UUID:-"$UUID_DEFAULT"}

  # 输入节点名，以系统的 hostname 作为默认
  if [ -s /etc/hostname ]; then
    NODE_NAME_DEFAULT="$(cat /etc/hostname)"
  elif [ $(type -p hostname) ]; then
    NODE_NAME_DEFAULT="$(hostname)"
  else
    NODE_NAME_DEFAULT="Sing-Box"
  fi
  reading "\n $(text_eval 13) " NODE_NAME
  NODE_NAME="${NODE_NAME:-"$NODE_NAME_DEFAULT"}"
}

check_dependencies() {
  # 如果是 Alpine，先升级 wget ，安装 systemctl-py 版
  if [ "$SYSTEM" = 'Alpine' ]; then
    CHECK_WGET=$(wget 2>&1 | head -n 1)
    grep -qi 'busybox' <<< "$CHECK_WGET" && ${PACKAGE_INSTALL[int]} wget >/dev/null 2>&1

    DEPS_CHECK=("bash" "python3" "rc-update")
    DEPS_INSTALL=("bash" "python3" "openrc")
    for ((g=0; g<${#DEPS_CHECK[@]}; g++)); do [ ! $(type -p ${DEPS_CHECK[g]}) ] && [[ ! "${DEPS[@]}" =~ "${DEPS_INSTALL[g]}" ]] && DEPS+=(${DEPS_INSTALL[g]}); done
    if [ "${#DEPS[@]}" -ge 1 ]; then
      info "\n $(text 7) ${DEPS[@]} \n"
      ${PACKAGE_UPDATE[int]} >/dev/null 2>&1
      ${PACKAGE_INSTALL[int]} ${DEPS[@]} >/dev/null 2>&1
    fi

    [ ! $(type -p systemctl) ] && wget https://raw.githubusercontent.com/gdraheim/docker-systemctl-replacement/master/files/docker/systemctl3.py -O /bin/systemctl && chmod a+x /bin/systemctl
  fi

  # 检测 Linux 系统的依赖，升级库并重新安装依赖
  unset DEPS_CHECK DEPS_INSTALL DEPS
  DEPS_CHECK=("wget" "systemctl" "ip" "unzip" "lsof" "bash")
  DEPS_INSTALL=("wget" "systemctl" "iproute2" "unzip" "lsof" "bash")
  for ((g=0; g<${#DEPS_CHECK[@]}; g++)); do [ ! $(type -p ${DEPS_CHECK[g]}) ] && [[ ! "${DEPS[@]}" =~ "${DEPS_INSTALL[g]}" ]] && DEPS+=(${DEPS_INSTALL[g]}); done
  if [ "${#DEPS[@]}" -ge 1 ]; then
    info "\n $(text 7) ${DEPS[@]} \n"
    ${PACKAGE_UPDATE[int]} >/dev/null 2>&1
    ${PACKAGE_INSTALL[int]} ${DEPS[@]} >/dev/null 2>&1
  else
    info "\n $(text 8) \n"
  fi
}

# 生成100年的自签证书
ssl_certificate() {
  mkdir -p $WORK_DIR/cert
  openssl ecparam -genkey -name prime256v1 -out $WORK_DIR/cert/private.key && openssl req -new -x509 -days 36500 -key $WORK_DIR/cert/private.key -out $WORK_DIR/cert/cert.pem -subj "/CN=$(awk -F . '{print $(NF-1)"."$NF}' <<< "$TLS_SERVER")"
}

# 生成 sing-box 配置文件
sing-box_json() {
  mkdir -p $WORK_DIR/conf
  cat > $WORK_DIR/conf/00_log.json << EOF
{
    "log":{
        "disabled":false,
        "level":"error",
        "output":"$WORK_DIR/logs/box.log",
        "timestamp":true
    }
}
EOF

  cat > $WORK_DIR/conf/01_outbounds.json << EOF
{
    "outbounds":[
        {
            "type":"direct",
            "tag":"direct",
            "domain_strategy":"$DOMAIN_STRATEG"
        },
        {
            "type":"direct",
            "tag":"warp-IPv4-out",
            "detour":"wireguard-out",
            "domain_strategy":"ipv4_only"
        },
        {
            "type":"direct",
            "tag":"warp-IPv6-out",
            "detour":"wireguard-out",
            "domain_strategy":"ipv6_only"
        },
        {
            "type":"wireguard",
            "tag":"wireguard-out",
            "server":"${WARP_ENDPOINT}",
            "server_port":2408,
            "local_address":[
                "172.16.0.2/32",
                "2606:4700:110:8a36:df92:102a:9602:fa18/128"
            ],
            "private_key":"YFYOAdbw1bKTHlNNi+aEjBM3BO7unuFC5rOkMRAz9XY=",
            "peer_public_key":"bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=",
            "reserved":[
                78,
                135,
                76
            ],
            "mtu":1280
        },
        {
            "type":"block",
            "tag":"block"
        }
    ]
}
EOF

  cat > $WORK_DIR/conf/02_route.json << EOF
{
    "route":{
        "geoip":{
            "download_url":"https://github.com/SagerNet/sing-geoip/releases/latest/download/geoip.db",
            "download_detour":"direct"
        },
        "geosite":{
            "download_url":"https://github.com/SagerNet/sing-geosite/releases/latest/download/geosite.db",
            "download_detour":"direct"
        },
        "rules":[
            {
                "geosite":[
                    "openai"
                ],
                "outbound":"warp-IPv6-out"
            },
            {
                "geosite":"cn",
                "geoip":"cn",
                "outbound":"direct"
            },
            {
                "geosite":"cn",
                "geoip":"cn",
                "domain":[
                    "6.ipchaxun.net"
                ],
                "outbound":"direct"
            }
        ]
    }
}
EOF

  # 禁止回国开启时，修改路由规则文件
  [[ "$RETURN" =~ 'y' ]] && local ROW_NUMS=($(grep -n '"outbound"' $WORK_DIR/conf/02_route.json | awk -F ':' '{print $1}')) && sed -i "${ROW_NUMS[1]}s/\(\"outbound\":\"\)[^\"]*/\1warp-IPv4-out/; ${ROW_NUMS[2]}s/\(\"outbound\":\"\)[^\"]*/\1warp-IPv6-out/;" $WORK_DIR/conf/02_route.json

  CHECK_PROTOCALS=b
  if [[ "${INSTALL_PROTOCALS[@]}" =~ "$CHECK_PROTOCALS" ]]; then
    SHADOWTLS_PASSWORD=$($TEMP_DIR/sing-box generate rand --base64 16)
    PORT_SHADOWTLS=$((START_PORT+$(awk -v target=$CHECK_PROTOCALS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCALS[*]}")))
    cat > $WORK_DIR/conf/11_SHADOWTLS_inbounds.json << EOF
{
    "inbounds":[
        {
            "type":"shadowtls",
            "sniff":true,
            "sniff_override_destination":true,
            "listen":"::",
            "listen_port":$PORT_SHADOWTLS,
            "detour":"shadowtls-in",
            "version":3,
            "users":[
                {
                    "password":"$UUID"
                }
            ],
            "handshake":{
                "server":"$TLS_SERVER",
                "server_port":443
            },
            "strict_mode":true
        },
        {
            "type":"shadowsocks",
            "tag":"shadowtls-in",
            "listen":"127.0.0.1",
            "network":"tcp",
            "method":"2022-blake3-aes-128-gcm",
            "password":"$SHADOWTLS_PASSWORD"
        }
    ]
}
EOF
  fi

  CHECK_PROTOCALS=$(asc "$CHECK_PROTOCALS" ++)
  if [[ "${INSTALL_PROTOCALS[@]}" =~ "$CHECK_PROTOCALS" ]]; then
    REALITY_KEYPAIR=$($TEMP_DIR/sing-box generate reality-keypair)
    REALITY_PRIVATE=$(awk '/PrivateKey/{print $NF}' <<< "$REALITY_KEYPAIR")
    REALITY_PUBLIC=$(awk '/PublicKey/{print $NF}' <<< "$REALITY_KEYPAIR")
    PORT_REALITY=$((START_PORT+$(awk -v target=$CHECK_PROTOCALS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCALS[*]}")))
    cat > $WORK_DIR/conf/12_REALITY_inbounds.json << EOF
{
    "inbounds":[
        {
            "type":"vless",
            "sniff":true,
            "sniff_override_destination":true,
            "tag":"reality-in",
            "listen":"::",
            "listen_port":$PORT_REALITY,
            "users":[
                {
                    "uuid":"$UUID",
                    "flow":"xtls-rprx-vision"
                }
            ],
            "tls":{
                "enabled":true,
                "server_name":"$TLS_SERVER",
                "reality":{
                    "enabled":true,
                    "handshake":{
                        "server":"$TLS_SERVER",
                        "server_port":443
                    },
                    "private_key":"$REALITY_PRIVATE",
                    "short_id":[
                        ""
                    ]
                }
            }
        }
    ]
}
EOF
  fi

  CHECK_PROTOCALS=$(asc "$CHECK_PROTOCALS" ++)
  if [[ "${INSTALL_PROTOCALS[@]}" =~ "$CHECK_PROTOCALS" ]]; then
    PORT_HYSTERIA2=$((START_PORT+$(awk -v target=$CHECK_PROTOCALS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCALS[*]}")))
    cat > $WORK_DIR/conf/13_HYSTERIA2_inbounds.json << EOF
{
    "inbounds":[
        {
            "type":"hysteria2",
            "sniff":true,
            "sniff_override_destination":true,
            "tag":"hysteria2-in",
            "listen":"::",
            "listen_port":$PORT_HYSTERIA2,
            "users":[
                {
                    "password":"$UUID"
                }
            ],
            "ignore_client_bandwidth":false,
            "obfs":{
                "type":"salamander",
                "password":"$UUID"
            },
            "tls":{
                "enabled":true,
                "server_name":"",
                "alpn":[
                    "h3"
                ],
                "min_version":"1.3",
                "max_version":"1.3",
                "certificate_path":"$WORK_DIR/cert/cert.pem",
                "key_path":"$WORK_DIR/cert/private.key"
            }
        }
    ]
}
EOF
  fi

  CHECK_PROTOCALS=$(asc "$CHECK_PROTOCALS" ++)
  if [[ "${INSTALL_PROTOCALS[@]}" =~ "$CHECK_PROTOCALS" ]]; then
    PORT_TUIC=$((START_PORT+$(awk -v target=$CHECK_PROTOCALS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCALS[*]}")))
    cat > $WORK_DIR/conf/14_TUIC_inbounds.json << EOF
{
    "inbounds":[
        {
            "type":"tuic",
            "sniff":true,
            "sniff_override_destination":true,
            "listen":"::",
            "listen_port":$PORT_TUIC,
            "users":[
                {
                    "uuid":"$UUID",
                    "password":"$UUID"
                }
            ],
            "congestion_control":"bbr",
            "tls":{
                "enabled":true,
                "alpn":[
                    "h3"
                ],
                "certificate_path":"$WORK_DIR/cert/cert.pem",
                "key_path":"$WORK_DIR/cert/private.key"
            }
        }
    ]
}
EOF
  fi

  CHECK_PROTOCALS=$(asc "$CHECK_PROTOCALS" ++)
  if [[ "${INSTALL_PROTOCALS[@]}" =~ "$CHECK_PROTOCALS" ]]; then
    PORT_SHADOWSOCKS=$((START_PORT+$(awk -v target=$CHECK_PROTOCALS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCALS[*]}")))
    cat > $WORK_DIR/conf/15_SHADOWSOCKS_inbounds.json << EOF
{
    "inbounds":[
        {
            "type":"shadowsocks",
            "sniff":true,
            "sniff_override_destination":true,
            "tag":"shadowsocks-in",
            "listen":"::",
            "listen_port":$PORT_SHADOWSOCKS,
            "method":"aes-128-gcm",
            "password":"$UUID"
        }
    ]
}
EOF
  fi

  CHECK_PROTOCALS=$(asc "$CHECK_PROTOCALS" ++)
  if [[ "${INSTALL_PROTOCALS[@]}" =~ "$CHECK_PROTOCALS" ]]; then
    PORT_TROJAN=$((START_PORT+$(awk -v target=$CHECK_PROTOCALS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCALS[*]}")))
    cat > $WORK_DIR/conf/16_TROJAN_inbounds.json << EOF
{
    "inbounds":[
        {
            "type":"trojan",
            "sniff":true,
            "sniff_override_destination":true,
            "tag":"trojan-in",
            "listen":"::",
            "listen_port":$PORT_TROJAN,
            "users":[
                {
                    "password":"$UUID"
                }
            ],
            "tls":{
                "enabled":true,
                "certificate_path":"$WORK_DIR/cert/cert.pem",
                "key_path":"$WORK_DIR/cert/private.key"
            }
        }
    ]
}
EOF
  fi

  CHECK_PROTOCALS=$(asc "$CHECK_PROTOCALS" ++)
  if [[ "${INSTALL_PROTOCALS[@]}" =~ "$CHECK_PROTOCALS" ]]; then
    PORT_VMESS_WS=$((START_PORT+$(awk -v target=$CHECK_PROTOCALS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCALS[*]}")))
    cat > $WORK_DIR/conf/17_VMESS_WS_inbounds.json << EOF
{
    "inbounds":[
        {
            "type":"vmess",
            "sniff":true,
            "sniff_override_destination":true,
            "tag":"vmess-ws-in",
            "listen":"::",
            "listen_port":${PORT_VMESS_WS},
            "tcp_fast_open":false,
            "proxy_protocol":false,
            "users":[
                {
                    "uuid":"${UUID}",
                    "alterId":0
                }
            ],
            "transport":{
                "type":"ws",
                "path":"/${UUID}-vmess",
                "max_early_data":2048,
                "early_data_header_name":"Sec-WebSocket-Protocol"
            }
        }
    ]
}
EOF
  fi

  CHECK_PROTOCALS=$(asc "$CHECK_PROTOCALS" ++)
  if [[ "${INSTALL_PROTOCALS[@]}" =~ "$CHECK_PROTOCALS" ]]; then
    PORT_VLESS_WS=$((START_PORT+$(awk -v target=$CHECK_PROTOCALS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCALS[*]}")))
    cat > $WORK_DIR/conf/18_VLESS_WS_inbounds.json << EOF
{
    "inbounds":[
        {
            "type":"vless",
            "sniff_override_destination":true,
            "sniff":true,
            "tag":"vless-ws-in",
            "listen":"::",
            "listen_port":${PORT_VLESS_WS},
            "tcp_fast_open":false,
            "proxy_protocol":false,
            "users":[
                {
                    "name":"sing-box",
                    "uuid":"${UUID}"
                }
            ],
            "transport":{
                "type":"ws",
                "path":"/${UUID}-vless",
                "max_early_data":2048,
                "early_data_header_name":"Sec-WebSocket-Protocol"
            },
            "tls":{
                "enabled":true,
                "server_name":"${VLESS_HOST_DOMAIN}",
                "min_version":"1.3",
                "max_version":"1.3",
                "certificate_path":"/etc/sing-box/cert/cert.pem",
                "key_path":"/etc/sing-box/cert/private.key"
            }
        }
    ]
}
EOF
  fi
}

# Sing-box 生成守护进程文件
sing-box_systemd() {
  cat > /etc/systemd/system/sing-box.service << EOF
[Unit]
Description=sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

[Service]
User=root
WorkingDirectory=$WORK_DIR
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
ExecStart=$WORK_DIR/sing-box run -C $WORK_DIR/conf/
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF
}

install_sing-box() {
  sing-box_variable
  [ ! -d /etc/systemd/system ] && mkdir -p /etc/systemd/system
  [ ! -d $WORK_DIR/logs ] && mkdir -p $WORK_DIR/logs
  ssl_certificate
  sing-box_json
  echo "$L" > $WORK_DIR/language
  cp $TEMP_DIR/sing-box $WORK_DIR
  sing-box_systemd

  # 再次检测状态，运行 Sing-box
  check_install
  [[ $STATUS = "$(text 27)" ]] && systemctl enable --now sing-box && info "\n Sing-box $(text 28) $(text 37) \n" || warning "\n Sing-box $(text 28) $(text 38) \n"

  # 如果 Alpine 系统，放到开机自启动
  if [ "$SYSTEM" = 'Alpine' ]; then
    cat > /etc/local.d/sing-box.start << EOF
#!/usr/bin/env bash

systemctl start sing-box
EOF
    chmod +x /etc/local.d/argox.start
    rc-update add local
  fi
}

export_list() {
  check_install
  if [ -s $WORK_DIR/list ]; then
    SERVER_IP=${SERVER_IP:-"$(sed -r "s/\x1B\[[0-9;]*[mG]//g" $WORK_DIR/list | sed -n "s/.*{name.*server:[ ]*\([^,]\+\).*/\1/pg" | sed -n '1p')"}
    UUID=${UUID:-"$(sed -r "s/\x1B\[[0-9;]*[mG]//g" $WORK_DIR/list | grep -m1 '{name' | sed -En 's/.*password:[ ]+[\"]*|.*uuid:[ ]+[\"]*(.*)/\1/gp' | sed "s/\([^,\"]\+\).*/\1/g")"}
    SHADOWTLS_PASSWORD=${SHADOWTLS_PASSWORD:-"$(sed -r "s/\x1B\[[0-9;]*[mG]//g" $WORK_DIR/list | sed -n 's/.*{name.*password:[ ]*\"\([^\"]\+\)".*shadow-tls.*/\1/pg')"}
    TLS_SERVER=${TLS_SERVER:-"$(sed -r "s/\x1B\[[0-9;]*[mG]//g" $WORK_DIR/list | grep -Em1 '{name.*shadow-tls|{name.*public-key' | sed -n "s/.*servername:[ ]\+\([^\,]\+\).*/\1/gp; s/.*host:[ ]\+\"\([^\"]\+\).*/\1/gp")"}
    NODE_NAME=${NODE_NAME:-"$(sed -r "s/\x1B\[[0-9;]*[mG]//g" $WORK_DIR/list | grep -m1 '{name' | sed 's/- {name:[ ]\+"//; s/[ ]\+ShadowTLS[ ]\+v3.*//; s/[ ]\+vless-reality-vision.*//; s/[ ]\+hysteria2.*//; s/[ ]\+tuic.*//; s/[ ]\+ss.*//; s/[ ]\+trojan.*//; s/[ ]\+trojan.*//; s/[ ]\+vmess[ ]\+ws.*//; s/[ ]\+vless[ ]\+.*//')"}
    REALITY_PUBLIC=${REALITY_PUBLIC:-"$(sed -n 's/.*{name.*public-key:[ ]*\([^,]\+\).*/\1/pg' $WORK_DIR/list)"}
    [ -s $WORK_DIR/conf/11_SHADOWTLS_inbounds.json ] && PORT_SHADOWTLS=$(sed -n '/listen_port/s/[^0-9]\+//gp' $WORK_DIR/conf/11_SHADOWTLS_inbounds.json)
    [ -s $WORK_DIR/conf/12_REALITY_inbounds.json ] && PORT_REALITY=$(sed -n '/listen_port/s/[^0-9]\+//gp' $WORK_DIR/conf/12_REALITY_inbounds.json)
    [ -s $WORK_DIR/conf/13_HYSTERIA2_inbounds.json ] && PORT_HYSTERIA2=$(sed -n '/listen_port/s/[^0-9]\+//gp' $WORK_DIR/conf/13_HYSTERIA2_inbounds.json)
    [ -s $WORK_DIR/conf/14_TUIC_inbounds.json ] && PORT_TUIC=$(sed -n '/listen_port/s/[^0-9]\+//gp' $WORK_DIR/conf/14_TUIC_inbounds.json)
    [ -s $WORK_DIR/conf/15_SHADOWSOCKS_inbounds.json ] && PORT_SHADOWSOCKS=$(sed -n '/listen_port/s/[^0-9]\+//gp' $WORK_DIR/conf/15_SHADOWSOCKS_inbounds.json)
    [ -s $WORK_DIR/conf/16_TROJAN_inbounds.json ] && PORT_TROJAN=$(sed -n '/listen_port/s/[^0-9]\+//gp' $WORK_DIR/conf/16_TROJAN_inbounds.json)
    [ -s $WORK_DIR/conf/17_VMESS_WS_inbounds.json ] && WS_SERVER_IP=$(grep -A2 "{name.*vmess[ ]\+ws" $WORK_DIR/list | awk -F'[][]' 'NR==3 {print $2}') && VMESS_HOST_DOMAIN=$(grep -A2 "{name.*vmess[ ]\+ws" $WORK_DIR/list | awk -F'[][]' 'NR==3 {print $4}') && PORT_VMESS_WS=$(sed -n '/listen_port/s/[^0-9]\+//gp' $WORK_DIR/conf/17_VMESS_WS_inbounds.json) && CDN=$(sed -n "s/.*{name.*vmess[ ]\+ws.*server:[ ]\+\([^,]\+\).*/\1/gp" $WORK_DIR/list)
    [ -s $WORK_DIR/conf/18_VLESS_WS_inbounds.json ] && WS_SERVER_IP=$(grep -A2 "{name.*vless[ ]\+ws" $WORK_DIR/list | awk -F'[][]' 'NR==3 {print $2}') && VLESS_HOST_DOMAIN=$(grep -A2 "{name.*vless[ ]\+ws" $WORK_DIR/list | awk -F'[][]' 'NR==3 {print $4}') && PORT_VLESS_WS=$(sed -n '/listen_port/s/[^0-9]\+//gp' $WORK_DIR/conf/18_VLESS_WS_inbounds.json) && CDN=$(sed -n "s/.*{name.*vless[ ]\+ws.*server:[ ]\+\([^,]\+\).*/\1/gp" $WORK_DIR/list)
  fi

  # IPv6 时的 IP 处理
  if [[ "$SERVER_IP" =~ : ]]; then
    SERVER_IP_1="[$SERVER_IP]"
    SERVER_IP_2="[[$SERVER_IP]]"
  else
    SERVER_IP_1="$SERVER_IP"
    SERVER_IP_2="$SERVER_IP"
  fi

  # 生成配置文件
  cat > $WORK_DIR/list << EOF
*******************************************
┌────────────────┐
│                │
│     $(warning "V2rayN")     │
│                │
└────────────────┘
EOF
  [ -n "$PORT_SHADOWTLS" ] && V2RAYN_PROTOCAL=ShadowTLS && V2RAYN_KERNEL=sing_box && cat >> $WORK_DIR/list << EOF

----------------------------
$(info "$(text_eval 54)

{
  \"log\":{
      \"level\":\"info\"
  },
  \"inbounds\":[
      {
          \"domain_strategy\":\"\",
          \"listen\":\"127.0.0.1\",
          \"listen_port\":${PORT_SHADOWTLS},
          \"sniff\":true,
          \"sniff_override_destination\":false,
          \"tag\":\"ShadowTLS\",
          \"type\":\"mixed\"
      }
  ],
  \"outbounds\":[
      {
          \"detour\":\"shadowtls-out\",
          \"domain_strategy\":\"\",
          \"method\":\"2022-blake3-aes-128-gcm\",
          \"password\":\"${SHADOWTLS_PASSWORD}\",
          \"type\":\"shadowsocks\",
          \"udp_over_tcp\":false
      },
      {
          \"domain_strategy\":\"\",
          \"password\":\"${UUID}\",
          \"server\":\"${SERVER_IP}\",
          \"server_port\":${PORT_SHADOWTLS},
          \"tag\":\"shadowtls-out\",
          \"tls\":{
              \"enabled\":true,
              \"server_name\":\"${TLS_SERVER}\"
          },
          \"type\":\"shadowtls\",
          \"version\":3
      }
  ]
}")
EOF
  [ -n "$PORT_REALITY" ] && cat >> $WORK_DIR/list << EOF

----------------------------
$(info "vless://${UUID}@${SERVER_IP_1}:${PORT_REALITY}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${TLS_SERVER}&fp=chrome&pbk=${REALITY_PUBLIC}&type=tcp&headerType=none#${NODE_NAME} vless-reality-vision")
EOF
  [ -n "$PORT_HYSTERIA2" ] && V2RAYN_PROTOCAL=Hysteria2 && V2RAYN_KERNEL=hysteria2 && cat >> $WORK_DIR/list << EOF

----------------------------
$(info "$(text_eval 54)

server: \"${SERVER_IP_1}:${PORT_HYSTERIA2}\"
auth: ${UUID}

bandwidth:
  up: 200 mbps
  down: 1000 mbps

obfs:
  type: salamander
  salamander:
    password: ${UUID}

tls:
  insecure: true

socks5:
  listen: 127.0.0.1:${PORT_HYSTERIA2}")
EOF
  [ -n "$PORT_TUIC" ] && V2RAYN_PROTOCAL=Tuic && V2RAYN_KERNEL=sing_box && cat >> $WORK_DIR/list << EOF

----------------------------
$(info "$(text_eval 54)

{
    \"log\":{
        \"level\":\"info\"
    },
    \"inbounds\":[
        {
            \"domain_strategy\":\"\",
            \"listen\":\"127.0.0.1\",
            \"listen_port\":${PORT_TUIC},
            \"sniff\":true,
            \"sniff_override_destination\":false,
            \"type\":\"mixed\"
        }
    ],
    \"outbounds\":[
        {
            \"congestion_control\":\"bbr\",
            \"domain_strategy\":\"\",
            \"heartbeat\":\"10s\",
            \"password\":\"${UUID}\",
            \"server\":\"${SERVER_IP}\",
            \"server_port\":${PORT_TUIC},
            \"tag\":\"proxy\",
            \"tls\":{
                \"alpn\":[
                    \"h3\",
                    \"spdy/3.1\"
                ],
                \"certificate\":\"\",
                \"disable_sni\":false,
                \"enabled\":true,
                \"insecure\":true,
                \"server_name\":\"\"
            },
            \"type\":\"tuic\",
            \"udp_relay_mode\":\"native\",
            \"uuid\":\"${UUID}\",
            \"zero_rtt_handshake\":false
        }
    ]
}")
EOF
  [ -n "$PORT_SHADOWSOCKS" ] && cat >> $WORK_DIR/list << EOF

----------------------------
$(info "ss://$(base64 -w0 <<< aes-128-gcm:${UUID}@${SERVER_IP_1}:${PORT_SHADOWSOCKS})#${NODE_NAME} ss")
EOF
  [ -n "$PORT_TROJAN" ] && cat >> $WORK_DIR/list << EOF

----------------------------
$(info "trojan://${UUID}@${SERVER_IP_1}:${PORT_TROJAN}?security=tls&type=tcp&headerType=none#\"${NODE_NAME} trojan\"

$(text 55)")
EOF
  [ -n "$PORT_VMESS_WS" ] && TYPE_HOST_DOMAIN=$VMESS_HOST_DOMAIN && TYPE_PORT_WS=$PORT_VMESS_WS && cat >> $WORK_DIR/list << EOF

----------------------------
$(info "vmess://$(base64 -w0 <<< "{ \"v\": \"2\", \"ps\": \"${NODE_NAME} vmess ws\", \"add\": \"${CDN}\", \"port\": \"80\", \"id\": \"${UUID}\", \"aid\": \"0\", \"scy\": \"none\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"${VMESS_HOST_DOMAIN}\", \"path\": \"/${UUID}-vmess\", \"tls\": \"\", \"sni\": \"\", \"alpn\": \"\" }" | sed "s/Cg==$//")

$(text_eval 52)")
EOF
  [ -n "$PORT_VLESS_WS" ] && TYPE_HOST_DOMAIN=$VLESS_HOST_DOMAIN && TYPE_PORT_WS=$PORT_VLESS_WS && cat >> $WORK_DIR/list << EOF

----------------------------
$(info "vless://${UUID}@${CDN}:443?encryption=none&security=tls&sni=${VLESS_HOST_DOMAIN}&type=ws&host=${VLESS_HOST_DOMAIN}&path=%2F${UUID}-vless%3Fed%3D2048#${NODE_NAME} vless ws

$(text_eval 52)")
EOF

  cat >> $WORK_DIR/list << EOF
*******************************************
┌────────────────┐
│                │
│  $(warning "Shadowrocket")  │
│                │
└────────────────┘
----------------------------
EOF
  [ -n "$PORT_SHADOWTLS" ] && cat >> $WORK_DIR/list << EOF

$(hint "ss://$(base64 -w0 <<< 2022-blake3-aes-128-gcm:${SHADOWTLS_PASSWORD}@${SERVER_IP_2}:${PORT_SHADOWTLS} | sed "s/Cg==$//")?shadow-tls=$(base64 -w0 <<< {\"version\":\"3\",\"host\":\"$TLS_SERVER\",\"password\":\"$UUID\" | sed "s/Cg==$//")#${NODE_NAME}%20ShadowTLS%20v3")
EOF
  [ -n "$PORT_REALITY" ] && cat >> $WORK_DIR/list << EOF

$(hint "vless://$(base64 -w0 <<< auto:$UUID@${SERVER_IP_2}:${PORT_REALITY} | sed "s/Cg==$//")?remarks=${NODE_NAME}%20vless-reality-vision&obfs=none&tls=1&peer=$TLS_SERVER&xtls=2&pbk=$REALITY_PUBLIC")
EOF
  [ -n "$PORT_HYSTERIA2" ] && cat >> $WORK_DIR/list << EOF

$(hint "hysteria2://${UUID}@${SERVER_IP_2}:${PORT_HYSTERIA2}?insecure=1&obfs=none&obfs-password=${UUID}#${NODE_NAME}%20hysteria2")
EOF
  [ -n "$PORT_TUIC" ] && cat >> $WORK_DIR/list << EOF

$(hint "tuic://${UUID}:${UUID}@${SERVER_IP_2}:${PORT_TUIC}?congestion_control=bbr&udp_relay_mode=native&alpn=h3&allow_insecure=1#${NODE_NAME}%20tuic")
EOF
  [ -n "$PORT_SHADOWSOCKS" ] && cat >> $WORK_DIR/list << EOF

$(hint "ss://$(base64 -w0 <<< aes-128-gcm:${UUID}@${SERVER_IP_2}:${PORT_SHADOWSOCKS} | sed "s/Cg==$//")#${NODE_NAME}%20ss")
EOF
  [ -n "$PORT_TROJAN" ] && cat >> $WORK_DIR/list << EOF

$(hint "trojan://${UUID}@${SERVER_IP_1}:${PORT_TROJAN}?allowInsecure=1#${NODE_NAME}%20trojan")
EOF
  [ -n "$PORT_VMESS_WS" ] && TYPE_HOST_DOMAIN=$VMESS_HOST_DOMAIN && TYPE_PORT_WS=$PORT_VMESS_WS && cat >> $WORK_DIR/list << EOF

----------------------------
$(hint "vmess://$(base64 -w0 <<< none:${UUID}@${CDN}:80 | sed "s/Cg==$//")?remarks=${NODE_NAME}%20vmess%20ws&obfsParam=${VMESS_HOST_DOMAIN}&path=/${UUID}-vmess&obfs=websocket&alterId=0

$(text_eval 52)")
EOF
  [ -n "$PORT_VLESS_WS" ] && TYPE_HOST_DOMAIN=$VLESS_HOST_DOMAIN && TYPE_PORT_WS=$PORT_VLESS_WS && cat >> $WORK_DIR/list << EOF

----------------------------
$(hint "vless://$(base64 -w0 <<< "auto:${UUID}@${CDN}:443" | sed "s/Cg==$//")?remarks=${NODE_NAME}%20vless%20ws&obfsParam=${VLESS_HOST_DOMAIN}&path=/${UUID}-vless?ed=2048&obfs=websocket&tls=1&peer=${VLESS_HOST_DOMAIN}&allowInsecure=1

$(text_eval 52)")
EOF
  cat >> $WORK_DIR/list << EOF
*******************************************
┌────────────────┐
│                │
│   $(warning "Clash Meta")   │
│                │
└────────────────┘
----------------------------
EOF
  [ -n "$PORT_SHADOWTLS" ] && cat >> $WORK_DIR/list << EOF

$(info "- {name: \"${NODE_NAME} ShadowTLS v3\", type: ss, server: ${SERVER_IP}, port: ${PORT_SHADOWTLS}, cipher: 2022-blake3-aes-128-gcm, password: \"${SHADOWTLS_PASSWORD}\", plugin: shadow-tls, client-fingerprint: chrome, plugin-opts: {host: \"${TLS_SERVER}\", password: \"${UUID}\", version: 3}}")
EOF
  [ -n "$PORT_REALITY" ] && cat >> $WORK_DIR/list << EOF

$(info "- {name: \"${NODE_NAME} vless-reality-vision\", type: vless, server: ${SERVER_IP}, port: ${PORT_REALITY}, uuid: ${UUID}, network: tcp, udp: true, tls: true, servername: ${TLS_SERVER}, flow: xtls-rprx-vision, client-fingerprint: chrome, reality-opts: {public-key: ${REALITY_PUBLIC}, short-id: \"\"} }")
EOF
  [ -n "$PORT_HYSTERIA2" ] && cat >> $WORK_DIR/list << EOF

$(info "- {name: \"${NODE_NAME} hysteria2\", type: hysteria2, server: ${SERVER_IP}, port: ${PORT_HYSTERIA2}, up: \"200 Mbps\", down: \"1000 Mbps\", password: ${UUID}, obfs: salamander, obfs-password: ${UUID}, skip-cert-verify: true}")
EOF
  [ -n "$PORT_TUIC" ] && cat >> $WORK_DIR/list << EOF

$(info "- {name: \"${NODE_NAME} tuic\", type: tuic, server: ${SERVER_IP}, port: ${PORT_TUIC}, uuid: ${UUID}, password: ${UUID}, alpn: [h3], disable-sni: true, reduce-rtt: true, request-timeout: 8000, udp-relay-mode: native, congestion-controller: bbr, skip-cert-verify: true}")
EOF
  [ -n "$PORT_SHADOWSOCKS" ] && cat >> $WORK_DIR/list << EOF

$(info "- {name: \"${NODE_NAME} ss\", server: ${SERVER_IP}, port: ${PORT_SHADOWSOCKS}, type: ss, cipher: aes-128-gcm, password: \"${UUID}\"}")
EOF
  [ -n "$PORT_TROJAN" ] && cat >> $WORK_DIR/list << EOF

$(info "- {name: \"${NODE_NAME} trojan\", type: trojan, server: ${SERVER_IP}, port: ${PORT_TROJAN}, password: ${UUID}, client-fingerprint: random, skip-cert-verify: true}")
EOF
  [ -n "$PORT_VMESS_WS" ] && TYPE_HOST_DOMAIN=$VMESS_HOST_DOMAIN && TYPE_PORT_WS=$PORT_VMESS_WS && cat >> $WORK_DIR/list << EOF

----------------------------
$(info "- {name: \"${NODE_NAME} vmess ws\", type: vmess, server: ${CDN}, port: 80, uuid: ${UUID}, udp: true, tls: false, alterId: 0, cipher: none, skip-cert-verify: true, network: ws, ws-opts: { path: \"/${UUID}-vmess\", headers: { Host: ${VMESS_HOST_DOMAIN}, max-early-data: 2048, early-data-header-name: Sec-WebSocket-Protocol} } }

$(text_eval 52)")
EOF
  [ -n "$PORT_VLESS_WS" ] && TYPE_HOST_DOMAIN=$VLESS_HOST_DOMAIN && TYPE_PORT_WS=$PORT_VLESS_WS && cat >> $WORK_DIR/list << EOF

----------------------------
$(info "- {name: \"${NODE_NAME} vless ws\", type: vless, server: ${CDN}, port: 443, uuid: ${UUID}, udp: true, tls: true, servername: ${VLESS_HOST_DOMAIN}, network: ws, skip-cert-verify: true, ws-opts: { path: \"/${UUID}-vless?ed=2048\", headers: { Host: ${VLESS_HOST_DOMAIN} } } }

$(text_eval 52)")
EOF
  cat >> $WORK_DIR/list << EOF
*******************************************
┌────────────────┐
│                │
│    $(warning "NekoBox")     │
│                │
└────────────────┘
EOF
  [ -n "$PORT_SHADOWTLS" ] && cat >> $WORK_DIR/list << EOF
----------------------------
$(hint "nekoray://custom#$(base64 -w0 <<< "{\"_v\":0,\"addr\":\"127.0.0.1\",\"cmd\":[\"\"],\"core\":\"internal\",\"cs\":\"{\n    \\\"password\\\": \\\"${UUID}\\\",\n    \\\"server\\\": \\\"${SERVER_IP_1}\\\",\n    \\\"server_port\\\": ${PORT_SHADOWTLS},\n    \\\"tag\\\": \\\"shadowtls-out\\\",\n    \\\"tls\\\": {\n        \\\"enabled\\\": true,\n        \\\"server_name\\\": \\\"addons.mozilla.org\\\"\n    },\n    \\\"type\\\": \\\"shadowtls\\\",\n    \\\"version\\\": 3\n}\n\",\"mapping_port\":0,\"name\":\"1-tls-not-use\",\"port\":1080,\"socks_port\":0}")

nekoray://shadowsocks#$(base64 -w0 <<< "{\"_v\":0,\"method\":\"2022-blake3-aes-128-gcm\",\"name\":\"2-ss-not-use\",\"pass\":\"${SHADOWTLS_PASSWORD}\",\"port\":0,\"stream\":{\"ed_len\":0,\"insecure\":false,\"mux_s\":0,\"net\":\"tcp\"},\"uot\":0}")

$(text 48)")
EOF
  [ -n "$PORT_REALITY" ] && cat >> $WORK_DIR/list << EOF
----------------------------
$(hint "vless://${UUID}@${SERVER_IP_1}:${PORT_REALITY}?security=reality&sni=${TLS_SERVER}&fp=chrome&pbk=${REALITY_PUBLIC}&type=tcp&flow=xtls-rprx-vision&encryption=none#${NODE_NAME}%20vless-reality-vision")
EOF
  [ -n "$PORT_HYSTERIA2" ] && cat >> $WORK_DIR/list << EOF
----------------------------
$(hint "hy2://${UUID}@${SERVER_IP_1}:${PORT_HYSTERIA2}?obfs=salamander&obfs-password=${UUID}&insecure=1#${NODE_NAME}%20hysteria2")
EOF
  [ -n "$PORT_TUIC" ] && cat >> $WORK_DIR/list << EOF
----------------------------
$(hint "tuic://${UUID}:${UUID}@${SERVER_IP_1}:${PORT_TUIC}?congestion_control=bbr&alpn=h3&udp_relay_mode=native&allow_insecure=1&disable_sni=1#${NODE_NAME}%20tuic")
EOF
  [ -n "$PORT_SHADOWSOCKS" ] && cat >> $WORK_DIR/list << EOF
----------------------------
$(hint "ss://$(base64 -w0 <<< aes-128-gcm:${UUID} | sed "s/Cg==$//")@${SERVER_IP_1}:${PORT_SHADOWSOCKS}#${NODE_NAME}%20ss")
EOF
  [ -n "$PORT_TROJAN" ] && cat >> $WORK_DIR/list << EOF
----------------------------
$(hint "trojan://${UUID}@${SERVER_IP_1}:${PORT_TROJAN}?security=tls&allowInsecure=1&fp=random&type=tcp#${NODE_NAME}%20trojan")
EOF
  [ -n "$PORT_VMESS_WS" ] && TYPE_HOST_DOMAIN=$VMESS_HOST_DOMAIN && TYPE_PORT_WS=$PORT_VMESS_WS && cat >> $WORK_DIR/list << EOF
----------------------------
$(hint "vmess://$(base64 -w0 <<< "{\"add\":\"${CDN}\",\"aid\":\"0\",\"host\":\"${VMESS_HOST_DOMAIN}\",\"id\":\"${NODE_NAME}\",\"net\":\"ws\",\"path\":\"/${UUID}-vmess\",\"port\":\"80\",\"ps\":\"${UUID} vmess ws\",\"scy\":\"none\",\"sni\":\"\",\"tls\":\"\",\"type\":\"\",\"v\":\"2\"}" | sed "s/Cg==$//")

$(text_eval 52)")
EOF
  [ -n "$PORT_VLESS_WS" ] && TYPE_HOST_DOMAIN=$VLESS_HOST_DOMAIN && TYPE_PORT_WS=$PORT_VLESS_WS && cat >> $WORK_DIR/list << EOF
----------------------------
$(hint "vless://${UUID}@${CDN}:443?security=tls&sni=${VLESS_HOST_DOMAIN}&type=ws&path=/${UUID}-vless?ed%3D2048&host=${VLESS_HOST_DOMAIN}&encryption=none#${NODE_NAME}%20vless%20ws

$(text_eval 52)")
EOF
  cat >> $WORK_DIR/list << EOF
*******************************************
EOF
  cat $WORK_DIR/list
}

# 更换各协议的监听端口
change_start_port() {
  OLD_PORTS=$(awk -F ':|,' '/listen_port/{print $2}' $WORK_DIR/conf/*)
  OLD_START_PORT=$(awk 'NR == 1 { min = $0 } { if ($0 < min) min = $0; count++ } END {print min}' <<< "$OLD_PORTS")
  OLD_CONSECUTIVE_PORTS=$(awk 'END { print NR }' <<< "$OLD_PORTS")
  enter_start_port $OLD_CONSECUTIVE_PORTS
  systemctl stop sing-box
  for ((a=0; a<$OLD_CONSECUTIVE_PORTS; a++)) do
    [ -s $WORK_DIR/conf/${CONF_FILES[a]} ] && sed -i "s/\(.*listen_port.*:\)$((OLD_START_PORT+a))/\1$((START_PORT+a))/" $WORK_DIR/conf/*
  done
  systemctl start sing-box
  sleep 2
  export_list
  [ "$(systemctl is-active sing-box)" = 'active' ] && info " Sing-box $(text 30) $(text 37) " || error " Sing-box $(text 30) $(text 38) "
}

uninstall() {
  if [ -d $WORK_DIR ]; then
    systemctl disable --now sing-box 2>/dev/null
    rm -rf $WORK_DIR $TEMP_DIR /etc/systemd/system/sing-box.service
    info "\n $(text 16) \n"
  else
    error "\n $(text 15) \n"
  fi

  # 如果 Alpine 系统，删除开机自启动
  [ "$SYSTEM" = 'Alpine' ] && ( rm -f /etc/local.d/argox.start; rc-update add local )
}

# Sing-box 的最新版本
version() {
  local ONLINE=$(wget -qO- "https://api.github.com/repos/SagerNet/sing-box/releases/latest" | grep "tag_name" | sed "s@.*\"v\(.*\)\",@\1@g")
  local LOCAL=$($WORK_DIR/sing-box version | awk '/version/{print $NF}')
  info "\n $(text_eval 40) "
  [[ -n "$ONLINE" && "$ONLINE" != "$LOCAL" ]] && reading "\n $(text 9) " UPDATE || info " $(text 41) "

  if [[ "$UPDATE" = [Yy] ]]; then
    check_system_info
    wget -O $TEMP_DIR/sing-box.tar.gz $GH_PROXY/https://github.com/SagerNet/sing-box/releases/download/v$ONLINE/sing-box-$ONLINE-linux-$ARCH.tar.gz
    tar xzf $TEMP_DIR/sing-box.tar.gz -C $TEMP_DIR sing-box-$ONLINE-linux-$ARCH/sing-box

    if [ -s $TEMP_DIR/sing-box-$ONLINE-linux-$ARCH/sing-box ]; then
      systemctl stop sing-box
      chmod +x $TEMP_DIR/sing-box-$ONLINE-linux-$ARCH/sing-box && mv $TEMP_DIR/sing-box-$ONLINE-linux-$ARCH/sing-box $WORK_DIR/sing-box
      systemctl start sing-box && sleep 2 && [ "$(systemctl is-active sing-box)" = 'active' ] && info " Sing-box $(text 28) $(text 37)" || error "Sing-box $(text 28) $(text 38) "
    else
      local error "\n $(text 42) "
    fi
  fi
}

# 禁止回国切换
switch_return() {
  local ROW_NUMS=($(grep -n '"outbound"' $WORK_DIR/conf/02_route.json | awk -F ':' '{print $1}'))
  if grep -q 'outbound.*direct' $WORK_DIR/conf/02_route.json; then
    sed -i "${ROW_NUMS[1]}s/\(\"outbound\":\"\)[^\"]*/\1warp-IPv4-out/; ${ROW_NUMS[2]}s/\(\"outbound\":\"\)[^\"]*/\1warp-IPv6-out/;" $WORK_DIR/conf/02_route.json
  else
    sed -i "${ROW_NUMS[1]},${ROW_NUMS[2]}s/\(\"outbound\":\"\)[^\"]*/\1direct/;" $WORK_DIR/conf/02_route.json
  fi

  systemctl restart sing-box && sleep 2
  if [ "$(systemctl is-active sing-box)" = 'active' ]; then
    grep -q 'outbound.*direct' $WORK_DIR/conf/02_route.json && info "\n $(text 57) $(text 27) $(text 37) " || info "\n $(text 57) $(text 28) $(text 37) "
  else
    error "Sing-box $(text 28) $(text 38) "
  fi
}

# 判断当前 Argo-X 的运行状态，并对应的给菜单和动作赋值
menu_setting() {
  OPTION[0]="0.  $(text 35)"
  ACTION[0]() { exit; }

  if [[ $STATUS =~ $(text 27)|$(text 28) ]]; then
    NOW_PORTS=$(awk -F ':|,' '/listen_port/{print $2}' $WORK_DIR/conf/*)
    NOW_START_PORT=$(awk 'NR == 1 { min = $0 } { if ($0 < min) min = $0; count++ } END {print min}' <<< "$NOW_PORTS")
    NOW_CONSECUTIVE_PORTS=$(awk 'END { print NR }' <<< "$NOW_PORTS")
    [ -s $WORK_DIR/sing-box ] && SING_BOX_VERSION="version: $($WORK_DIR/sing-box version | awk '/version/{print $NF}')"
    [ -s $WORK_DIR/conf/02_route.json ] && { grep -q 'direct' $WORK_DIR/conf/02_route.json && RETURN_STATUS=$(text 27) || RETURN_STATUS=$(text 28); }
    OPTION[1]="1.  $(text 29)"
    [ "$STATUS" = "$(text 28)" ] && OPTION[2]="2.  $(text 27) Sing-box" || OPTION[2]="2.  $(text 28) Sing-box"
    OPTION[3]="3.  $(text 30)"
    OPTION[4]="4.  $(text 31)"
    OPTION[5]="5.  $(text 32)"
    [ "$RETURN_STATUS" = "$(text 27)" ] && OPTION[6]="6.  $(text 28) $(text 57)" || OPTION[6]="6.  $(text 27) $(text 57)"
    OPTION[7]="7.  $(text 33)"
    OPTION[8]="8.  $(text 58)"

    ACTION[1]() { export_list; }
    [ "$STATUS" = "$(text 28)" ] && ACTION[2]() { systemctl disable --now sing-box; [ "$(systemctl is-active sing-box)" = 'inactive' ] && info " Sing-box $(text 27) $(text 37)" || error " Sing-box $(text 27) $(text 38) "; } || ACTION[2]() { systemctl enable --now sing-box && [ "$(systemctl is-active sing-box)" = 'active' ] && info " Sing-box $(text 28) $(text 37)" || error " Sing-box $(text 28) $(text 38) "; }
    ACTION[3]() { change_start_port; }
    ACTION[4]() { version; }
    ACTION[5]() { bash <(wget -qO- --no-check-certificate "https://raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master/tcp.sh"); exit; }
    ACTION[6]() { switch_return; }
    ACTION[7]() { uninstall; }
    ACTION[8]() { bash <(wget -qO- https://raw.githubusercontent.com/fscarmen/argox/main/argox.sh) -$L; exit; }

  else
    OPTION[1]="1.  $(text 34)"
    OPTION[2]="2.  $(text 32)"
    OPTION[3]="3.  $(text 58)"

    ACTION[1]() { install_sing-box; export_list; }
    ACTION[2]() { bash <(wget -qO- --no-check-certificate "https://raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master/tcp.sh"); exit; }
    ACTION[3]() { bash <(wget -qO- https://raw.githubusercontent.com/fscarmen/argox/main/argox.sh) -$L; exit; }
  fi
}

menu() {
  clear
  hint " $(text 2) "
  echo -e "======================================================================================================================\n"
  info " $(text 17):$VERSION\n $(text 18):$(text 1)\n $(text 19):\n\t $(text 20):$SYS\n\t $(text 21):$(uname -r)\n\t $(text 22):$ARCHITECTURE\n\t $(text 23):$VIRT "
  info "\t IPv4: $WAN4 $WARPSTATUS4 $COUNTRY4  $ASNORG4 "
  info "\t IPv6: $WAN6 $WARPSTATUS6 $COUNTRY6  $ASNORG6 "
  info "\t Sing-box: $STATUS\t $SING_BOX_VERSION "
  [ -n "$NOW_START_PORT" ] && info "\t $(text_eval 45) "
  [ -n "$RETURN_STATUS" ] && info "\t $(text 57): $RETURN_STATUS "
  echo -e "\n======================================================================================================================\n"
  for ((b=1;b<${#OPTION[*]};b++)); do hint " ${OPTION[b]} "; done
  hint " ${OPTION[0]} "
  reading "\n $(text 24) " CHOOSE

  # 输入必须是数字且少于等于最大可选项
  if grep -qE "^[0-9]$" <<< "$CHOOSE" && [ "$CHOOSE" -lt "${#OPTION[*]}" ]; then
    ACTION[$CHOOSE]
  else
    warning " $(text 36) [0-$((${#OPTION[*]}-1))] " && sleep 1 && menu
  fi
}

# 传参
[[ "$*" =~ -[Ee] ]] && L=E
[[ "$*" =~ -[Cc] ]] && L=C

while getopts ":P:p:OoUuVvNnBbRr" OPTNAME; do
  case "$OPTNAME" in
    'P'|'p' ) START_PORT=$OPTARG; select_language; check_install; [ "$STATUS" = "$(text 26)" ] && error "\n Sing-box $(text 26) "; change_start_port; exit 0 ;;
    'O'|'o' ) select_language; check_install; [ "$STATUS" = "$(text 26)" ] && error "\n Sing-box $(text 26) "; [ "$STATUS" = "$(text 28)" ] && ( systemctl disable --now sing-box; [ "$(systemctl is-active sing-box)" = 'inactive' ] && info " Sing-box $(text 27) $(text 37)" ) || ( systemctl enable --now sing-box && [ "$(systemctl is-active sing-box)" = 'active' ] && info " Sing-box $(text 28) $(text 37)" ); exit 0;;
    'U'|'u' ) select_language; uninstall; exit 0 ;;
    'N'|'n' ) select_language; [ ! -s $WORK_DIR/list ] && error " Sing-box $(text 26) "; export_list; exit 0 ;;
    'V'|'v' ) select_language; check_arch; version; exit 0 ;;
    'B'|'b' ) select_language; bash <(wget -qO- --no-check-certificate "https://raw.githubusercontents.com/ylx2016/Linux-NetSpeed/master/tcp.sh"); exit ;;
    'R'|'r' ) select_language; switch_return; exit 0 ;;
  esac
done

select_language
check_root
check_arch
check_system_info
check_dependencies
check_system_ip
check_install
menu_setting
menu