#!/usr/bin/env bash

# 当前脚本版本号
VERSION='beta 1'

# 各变量默认值
CDN='https://ghproxy.com'
TEMP_DIR='/tmp/sing-box'
WORK_DIR='/etc/sing-box'
START_PORT_DEFAULT='8881'
CONSECUTIVE_PORTS=6
MIN_PORT=1000
MAX_PORT=65525
TLS_SERVER=addons.mozilla.org

trap "rm -rf $TEMP_DIR >/dev/null 2>&1 ; echo -e '\n' ;exit 1" INT QUIT TERM EXIT

mkdir -p $TEMP_DIR

E[0]="Language:\n 1. English (default) \n 2. 简体中文"
C[0]="${E[0]}"
E[1]="Sing-box's Family Bucket"
C[1]="Sing-box 全家桶"
E[2]="This project is designed to add sing-box support for multiple protocols to VPS, details: [https://github.com/fscarmen/sing-box]\n Script Features:\n\t • Deploy multiple protocols with one click, there is always one for you!\n\t • Built-in warp chained proxy to unlock chatGPT.\n\t • No domain name is required.\n\t • Support system: Ubuntu, Debian, CentOS, Alpine and Arch Linux 3.\n\t • Support architecture: AMD,ARM and s390x\n"
C[2]="本项目专为 VPS 添加 sing-box 支持的多种协议, 详细说明: [https://github.com/fscarmen/sing-box]\n 脚本特点:\n\t • 一键部署多协议，总有一款适合你\n\t • 内置 warp 链式代理解锁 chatGPT\n\t • 不需要域名\n\t • 智能判断操作系统: Ubuntu 、Debian 、CentOS 、Alpine 和 Arch Linux,请务必选择 LTS 系统\n\t • 支持硬件结构类型: AMD 和 ARM\n"
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
E[11]="Please enter the starting port number. Must be \${MIN_PORT} - \${MAX_PORT}, consecutive \${CONSECUTIVE_PORTS} free ports are required \(Default is: \${START_PORT_DEFAULT}\):"
C[11]="请输入开始的端口号，必须是 \${MIN_PORT} - \${MAX_PORT}，需要连续\${CONSECUTIVE_PORTS}个空闲的端口 \(默认为: \${START_PORT_DEFAULT}\):"
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
E[45]="Ports used: \${START_PORT} - \$((START_PORT+CONSECUTIVE_PORTS))"
C[45]="使用端口: \${START_PORT} - \$((START_PORT+CONSECUTIVE_PORTS))"
E[46]="Warp / warp-go was detected to be running. Please close and run this script again."
C[46]="检测到 warp / warp-go 正在运行，请关闭后再次运行本脚本"
E[47]="No server ip, script exits. Feedback:[https://github.com/fscarmen/sing-box/issues]"
C[47]="没有 server ip，脚本退出，问题反馈:[https://github.com/fscarmen/sing-box/issues]"
E[48]="ShadowTLS - Copy the above two Neko links and manually set up the chained proxies in order. Tutorial: https://github.com/fscarmen/sing-box/blob/main/README.md#sekobox-%E8%AE%BE%E7%BD%AE-shadowtls-%E6%96%B9%E6%B3%95"
C[48]="ShadowTLS - 复制上面两条 Neko links 进去，并按顺序手动设置链式代理，详细教程: https://github.com/fscarmen/sing-box/blob/main/README.md#sekobox-%E8%AE%BE%E7%BD%AE-shadowtls-%E6%96%B9%E6%B3%95"

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
    wget -qO $TEMP_DIR/sing-box.tar.gz $CDN/https://github.com/SagerNet/sing-box/releases/download/v$ONLINE/sing-box-$ONLINE-linux-$ARCH.tar.gz >/dev/null 2>&1
    tar xzf $TEMP_DIR/sing-box.tar.gz -C $TEMP_DIR sing-box-$ONLINE-linux-$ARCH/sing-box >/dev/null 2>&1
    mv $TEMP_DIR/sing-box-$ONLINE-linux-$ARCH/sing-box $TEMP_DIR >/dev/null 2>&1
    }&
  fi
}

check_system_info() {
  # 判断虚拟化，选择 Wireguard内核模块 还是 Wireguard-Go
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

check_system_ip() {
  # 检测 IPv4 IPv6 信息，WARP Ineterface 开启，普通还是 Plus账户 和 IP 信息
  IP4=$(wget -4 -qO- --no-check-certificate --user-agent=Mozilla --tries=2 --timeout=3 http://ip-api.com/json/) &&
  WAN4=$(expr "$IP4" : '.*query\":[ ]*\"\([^"]*\).*') &&
  COUNTRY4=$(expr "$IP4" : '.*country\":[ ]*\"\([^"]*\).*') &&
  ASNORG4=$(expr "$IP4" : '.*isp\":[ ]*\"\([^"]*\).*') &&
  [[ "$L" = C && -n "$COUNTRY4" ]] && COUNTRY4=$(translate "$COUNTRY4")

  IP6=$(wget -6 -qO- --no-check-certificate --user-agent=Mozilla --tries=2 --timeout=3 https://api.ip.sb/geoip) &&
  WAN6=$(expr "$IP6" : '.*ip\":[ ]*\"\([^"]*\).*') &&
  COUNTRY6=$(expr "$IP6" : '.*country\":[ ]*\"\([^"]*\).*') &&
  ASNORG6=$(expr "$IP6" : '.*isp\":[ ]*\"\([^"]*\).*') &&
  [[ "$L" = C && -n "$COUNTRY6" ]] && COUNTRY6=$(translate "$COUNTRY6")
}

# 输入起始 port 函数
enter_start_port() {
  local PORT_ERROR_TIME=6
  while true; do
    unset IN_USED
    (( PORT_ERROR_TIME-- )) || true
    [ "$PORT_ERROR_TIME" = 0 ] && error "\n $(text 3) \n" || reading "\n $(text_eval 11) " START_PORT
    START_PORT=${START_PORT:-"$START_PORT_DEFAULT"}
    if [[ "$START_PORT" =~ ^[1-9][0-9]{3,4}$ && "$START_PORT" -ge "$MIN_PORT" && "$START_PORT" -le "$MAX_PORT" ]]; then
      for port in $(eval echo {$START_PORT..$((START_PORT+CONSECUTIVE_PORTS))}); do
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
  elif [ -n "$WAN6" ]; then
    SERVER_IP_DEFAULT=$WAN6
  fi

  reading "\n $(text_eval 10) " SERVER_IP
  SERVER_IP=${SERVER_IP:-"$SERVER_IP_DEFAULT"}
  [ -z "$SERVER_IP" ] && error " $(text 47) "
  [ -n "$SERVER_IP" ] && [ -z "$START_PORT" ] && enter_start_port

  wait
  UUID_DEFAULT=$($TEMP_DIR/sing-box generate uuid)
  [ -z "$UUID" ] && reading "\n $(text_eval 12) " UUID
  local UUID_ERROR_TIME=5
  until [[ -z "$UUID" || "$UUID" =~ ^[A-F0-9a-f]{8}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{12}$ ]]; do
    (( UUID_ERROR_TIME-- )) || true
    [ "$UUID_ERROR_TIME" = 0 ] && error "\n $(text 3) \n" || reading "\n $(text_eval 4) \n" UUID
  done
  UUID=${UUID:-"$UUID_DEFAULT"}

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
  openssl ecparam -genkey -name prime256v1 -out $WORK_DIR/cert/private.key && openssl req -new -x509 -days 36500 -key $WORK_DIR/cert/private.key -out $WORK_DIR/cert/cert.pem -subj "/CN=bing.com"
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
            "tag":"direct"
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
            "server":"162.159.192.1",
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
            }
        ]
    }
}
EOF

  SHADOWTLS_PASSWORD=$($TEMP_DIR/sing-box generate rand --base64 16)
  cat > $WORK_DIR/conf/11_SHADOWTLS_inbounds.json << EOF
{
    "inbounds":[
        {
            "type":"shadowtls",
            "sniff":true,
            "sniff_override_destination":true,
            "listen":"::",
            "listen_port":$START_PORT,
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

  REALITY_KEYPAIR=$($TEMP_DIR/sing-box generate reality-keypair)
  REALITY_PRIVATE=$(awk '/PrivateKey/{print $NF}' <<< "$REALITY_KEYPAIR")
  REALITY_PUBLIC=$(awk '/PublicKey/{print $NF}' <<< "$REALITY_KEYPAIR")
  cat > $WORK_DIR/conf/12_REALITY_inbounds.json << EOF
{
    "inbounds":[
        {
            "type":"vless",
            "sniff":true,
            "sniff_override_destination":true,
            "tag":"reality-in",
            "listen":"::",
            "listen_port":$((START_PORT+1)),
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

  cat > $WORK_DIR/conf/13_HYSTERIA2_inbounds.json << EOF
{
    "inbounds":[
        {
            "type":"hysteria2",
            "sniff":true,
            "sniff_override_destination":true,
            "tag":"hysteria2-in",
            "listen":"::",
            "listen_port":$((START_PORT+2)),
            "users":[
                {
                    "password":"$UUID"
                }
            ],
            "ignore_client_bandwidth":true,
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

  cat > $WORK_DIR/conf/14_TUIC_inbounds.json << EOF
{
    "inbounds":[
        {
            "type":"tuic",
            "sniff":true,
            "sniff_override_destination":true,            
            "listen":"::",
            "listen_port":$((START_PORT+3)),
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

  cat > $WORK_DIR/conf/15_SHADOWSOCKS_inbounds.json << EOF
{
    "inbounds":[
        {
            "type":"shadowsocks",
            "sniff":true,
            "sniff_override_destination":true,
            "tag":"shadowsocks-in",
            "listen":"::",
            "listen_port":$((START_PORT+4)),
            "method":"aes-256-gcm",
            "password":"$UUID"
        }
    ]
}
EOF

  cat > $WORK_DIR/conf/16_TROJAN_inbounds.json << EOF
{
    "inbounds":[
        {
            "type":"trojan",
            "sniff":true,
            "sniff_override_destination":true,
            "tag":"trojan-in",
            "listen":"::",
            "listen_port":$((START_PORT+5)),
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
    SERVER_IP=${SERVER_IP:-"$(sed -n "s/.*name.*server:[ ]*\([^,]\+\).*shadow-tls.*/\1/pg" $WORK_DIR/list)"}
    UUID=${UUID:-"$(awk '/auth:[ ]+/{print $NF}' $WORK_DIR/list)"}
    SHADOWTLS_PASSWORD=${SHADOWTLS_PASSWORD:-"$(sed -n 's/.*name.*password:[ ]*\"\([^\"]\+\)".*shadow-tls.*/\1/pg' $WORK_DIR/list)"}
    TLS_SERVER=${TLS_SERVER:-"$(awk '/[ ]+sni:[ ]+/{print $NF}' $WORK_DIR/list)"}
    NODE_NAME=${NODE_NAME:-"$(sed -n 's/.*name:[ ]*\"\([^\S]\+\)[ ]\+ShadowTLS[ ]*v3.*/\1/pg' $WORK_DIR/list)"}
    REALITY_PUBLIC=${REALITY_PUBLIC:-"$(sed -n 's/.*name.*public-key:[ ]*\([^,]\+\).*/\1/pg' $WORK_DIR/list)"}
    START_PORT=${START_PORT:-"$(sed -n 's/.*name.*port:[ ]*\([0-9]\+\).*shadow-tls.*/\1/pg' $WORK_DIR/list)"}
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
V2rayN:
----------------------------
shadowTLS 我不会设置，知道的朋友请告诉我
----------------------------
vless://${UUID}@${SERVER_IP_2}:$((START_PORT+1))?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${TLS_SERVER}&fp=chrome&pbk=${REALITY_PUBLIC}&type=tcp&headerType=none#${NODE_NAME}%20vless-reality-vision
----------------------------
hysteria2 配置文件内容，需要更新 hysteria2 内核
server: "${SERVER_IP_1}:$((START_PORT+2))"
auth: ${UUID}

bandwidth:
  up: 200 mbps
  down: 1000 mbps
  
tls:
  insecure: true

socks5:
  listen: 127.0.0.1:$((START_PORT+2))
----------------------------
Tuic 我不会设置，知道的朋友请告诉我
----------------------------
ss://$(base64 -w0 <<< aes-256-gcm:${UUID}@${SERVER_IP_2}:$((START_PORT+4)))#${NODE_NAME}%20ss
----------------------------
trojan://${UUID}@${SERVER_IP_2}:$((START_PORT+5))?security=tls&type=tcp&headerType=none#${NODE_NAME}%20trojan
请自行把 tls 里的 inSecure 设置为 true
*******************************************
小火箭 Shadowrocket:
----------------------------
ss://$(base64 -w0 <<< 2022-blake3-aes-128-gcm:${SHADOWTLS_PASSWORD}@${SERVER_IP_2}:${START_PORT})?shadow-tls=$(base64 -w0 <<< {\"version\":\"3\",\"host\":\"$TLS_SERVER\",\"password\":\"$UUID\"})#${NODE_NAME}%20ShadowTLS%20v3
----------------------------
vless://$(base64 -w0 <<< auto:$UUID@${SERVER_IP_2}:$((START_PORT+1)))?remarks=${NODE_NAME}%20vless-reality-vision&obfs=none&tls=1&peer=$TLS_SERVER&xtls=2&pbk=$REALITY_PUBLIC
----------------------------
hysteria2://${UUID}@${SERVER_IP_2}:$((START_PORT+2))?insecure=1&obfs=none#${NODE_NAME}%20hysteria2
----------------------------
tuic://${UUID}:${UUID}@${SERVER_IP_2}:$((START_PORT+3))?congestion_control=bbr&udp_relay_mode=native&alpn=h3&allow_insecure=1#${NODE_NAME}%20tuic
----------------------------
ss://$(base64 -w0 <<< aes-256-gcm:${UUID}@${SERVER_IP_2}:$((START_PORT+4)))#${NODE_NAME}%20ss
----------------------------
trojan://${UUID}@${SERVER_IP_1}:$((START_PORT+5))?allowInsecure=1#${NODE_NAME}%20trojan
*******************************************
Clash Meta:
----------------------------
- {name: "${NODE_NAME} ShadowTLS v3", type: ss, server: ${SERVER_IP}, port: ${START_PORT}, cipher: 2022-blake3-aes-128-gcm, password: "${SHADOWTLS_PASSWORD}", plugin: shadow-tls, client-fingerprint: chrome, plugin-opts: {host: "${TLS_SERVER}", password: "${UUID}", version: 3}}
- {name: "${NODE_NAME} vless-reality-vision", type: vless, server: ${SERVER_IP}, port: $((START_PORT+1)), uuid: ${UUID}, network: tcp, udp: true, tls: true, servername: ${TLS_SERVER}, flow: xtls-rprx-vision, client-fingerprint: chrome, reality-opts: {public-key: ${REALITY_PUBLIC}, short-id: ""} }
- {name: "${NODE_NAME} hysteria2", type: hysteria2, server: ${SERVER_IP}, port: $((START_PORT+2)), up: "200 Mbps", down: "1000 Mbps", password: ${UUID}, skip-cert-verify: true}
- {name: "${NODE_NAME} tuic", type: tuic, server: ${SERVER_IP}, port: $((START_PORT+3)), uuid: ${UUID}, password: ${UUID}, alpn: [h3], disable-sni: true, reduce-rtt: true, request-timeout: 8000, udp-relay-mode: native, congestion-controller: bbr, skip-cert-verify: true}
- {name: "${NODE_NAME} ss", server: ${SERVER_IP}, port: $((START_PORT+4)), type: ss, cipher: aes-256-gcm, password: "${UUID}"}
- {name: "${NODE_NAME} trojan", type: trojan, server: ${SERVER_IP}, port: $((START_PORT+5)), password: ${UUID}, client-fingerprint: random, skip-cert-verify: true}
*******************************************
NekoBox:
----------------------------
nekoray://custom#$(base64 -w0 <<< "{\"_v\":0,\"addr\":\"127.0.0.1\",\"cmd\":[\"\"],\"core\":\"internal\",\"cs\":\"{\n    \\\"password\\\": \\\"${UUID}\\\",\n    \\\"server\\\": \\\"${SERVER_IP_1}\\\",\n    \\\"server_port\\\": ${START_PORT},\n    \\\"tag\\\": \\\"shadowtls-out\\\",\n    \\\"tls\\\": {\n        \\\"enabled\\\": true,\n        \\\"server_name\\\": \\\"addons.mozilla.org\\\"\n    },\n    \\\"type\\\": \\\"shadowtls\\\",\n    \\\"version\\\": 3\n}\n\",\"mapping_port\":0,\"name\":\"1-tls-not-use\",\"port\":1080,\"socks_port\":0}")

nekoray://shadowsocks#$(base64 -w0 <<< "{\"_v\":0,\"method\":\"2022-blake3-aes-128-gcm\",\"name\":\"2-ss-not-use\",\"pass\":\"${SHADOWTLS_PASSWORD}\",\"port\":0,\"stream\":{\"ed_len\":0,\"insecure\":false,\"mux_s\":0,\"net\":\"tcp\"},\"uot\":0}")

$(text 48)
----------------------------
vless://${UUID}@${SERVER_IP_1}:$((START_PORT+1))?security=reality&sni=${TLS_SERVER}&fp=chrome&pbk=${REALITY_PUBLIC}&type=tcp&flow=xtls-rprx-vision&encryption=none#${NODE_NAME}%20vless-reality-vision
----------------------------
hy2://${UUID}@${SERVER_IP_1}:$((START_PORT+2))?insecure=1#${NODE_NAME}%20hysteria2
----------------------------
tuic://${UUID}:${UUID}@${SERVER_IP_1}:$((START_PORT+3))?congestion_control=bbr&alpn=h3&udp_relay_mode=native&allow_insecure=1&disable_sni=1#${NODE_NAME}%20tuic
----------------------------
ss://$(base64 -w0 <<< aes-256-gcm:${UUID} | sed "s/Cg==$//")@${SERVER_IP_1}:$((START_PORT+4))#${NODE_NAME}%20ss
----------------------------
trojan://${UUID}@${SERVER_IP_1}:$((START_PORT+5))?security=tls&allowInsecure=1&fp=random&type=tcp#${NODE_NAME}%20trojan
*******************************************
EOF
  cat $WORK_DIR/list
}

# 更换各协议的监听端口
change_start_port() {
  enter_start_port
  systemctl stop sing-box
  CONF_FILES=("11_SHADOWTLS_inbounds.json" "12_REALITY_inbounds.json" "13_HYSTERIA2_inbounds.json" "14_TUIC_inbounds.json" "15_SHADOWSOCKS_inbounds.json" "16_TROJAN_inbounds.json")
  for ((a=0; a<${#CONF_FILES[@]}; a++)) do
    [ -s $WORK_DIR/conf/${CONF_FILES[a]} ] && sed -i "s/\(.*listen_port.*:\)[0-9]\+/\1$((START_PORT+a))/" $WORK_DIR/conf/${CONF_FILES[a]}
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
    wget -O $TEMP_DIR/sing-box.tar.gz $CDN/https://github.com/SagerNet/sing-box/releases/download/v$ONLINE/sing-box-$ONLINE-linux-$ARCH.tar.gz
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

# 判断当前 Argo-X 的运行状态，并对应的给菜单和动作赋值
menu_setting() {
  OPTION[0]="0.  $(text 35)"
  ACTION[0]() { exit; }

  if [[ $STATUS =~ $(text 27)|$(text 28) ]]; then
    [ -s $WORK_DIR/list ] && START_PORT=$(grep 'name.*shadow-tls' $WORK_DIR/list | sed "s/.*port:[ ]\+\([^,]\+\).*/\1/")
    [ -s $WORK_DIR/sing-box ] && SING_BOX_INFO="version: $($WORK_DIR/sing-box version | awk '/version/{print $NF}') $(text_eval 45)"
    OPTION[1]="1.  $(text 29)"
    [ "$STATUS" = "$(text 28)" ] && OPTION[2]="2.  $(text 27) Sing-box" || OPTION[2]="2.  $(text 28) Sing-box"
    OPTION[3]="3.  $(text 30)"
    OPTION[4]="4.  $(text 31)"
    OPTION[5]="5.  $(text 32)"
    OPTION[6]="6.  $(text 33)"

    ACTION[1]() { export_list; }
    [ "$STATUS" = "$(text 28)" ] && ACTION[2]() { systemctl disable --now sing-box; [ "$(systemctl is-active sing-box)" = 'inactive' ] && info " Sing-box $(text 27) $(text 37)" || error " Sing-box $(text 27) $(text 38) "; } || ACTION[2]() { systemctl enable --now sing-box && [ "$(systemctl is-active sing-box)" = 'active' ] && info " Sing-box $(text 28) $(text 37)" || error " Sing-box $(text 28) $(text 38) "; }
    ACTION[3]() { change_start_port; }
    ACTION[4]() { version; }
    ACTION[5]() { bash <(wget -qO- --no-check-certificate "https://raw.githubusercontents.com/ylx2016/Linux-NetSpeed/master/tcp.sh"); exit; }
    ACTION[6]() { uninstall; }

  else
    OPTION[1]="1.  $(text 34)"
    OPTION[2]="2.  $(text 32)"

    ACTION[1]() { install_sing-box; export_list; }
    ACTION[2]() { bash <(wget -qO- --no-check-certificate "https://raw.githubusercontents.com/ylx2016/Linux-NetSpeed/master/tcp.sh"); exit; }
  fi
}

menu() {
  clear
  hint " $(text 2) "
  echo -e "======================================================================================================================\n"
  info " $(text 17):$VERSION\n $(text 18):$(text 1)\n $(text 19):\n\t $(text 20):$SYS\n\t $(text 21):$(uname -r)\n\t $(text 22):$ARCHITECTURE\n\t $(text 23):$VIRT "
  info "\t IPv4: $WAN4 $WARPSTATUS4 $COUNTRY4  $ASNORG4 "
  info "\t IPv6: $WAN6 $WARPSTATUS6 $COUNTRY6  $ASNORG6 "
  info "\t Sing-box: $STATUS\t $SING_BOX_INFO"
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

while getopts ":PpUuVvNnBb" OPTNAME; do
  case "$OPTNAME" in
    'P'|'p' ) select_language; change_start_port; exit 0 ;;
    'U'|'u' ) select_language; uninstall; exit 0;;
    'N'|'n' ) select_language; [ ! -s $WORK_DIR/list ] && error " Sing-box $(text 26) "; export_list; exit 0 ;;
    'V'|'v' ) select_language; check_arch; version; exit 0 ;;
    'B'|'b' ) select_language; bash <(wget -qO- --no-check-certificate "https://raw.githubusercontents.com/ylx2016/Linux-NetSpeed/master/tcp.sh"); exit ;;
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