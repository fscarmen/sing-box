#!/usr/bin/env bash

# 当前脚本版本号
VERSION='v1.1.1'

# 各变量默认值
GH_PROXY='https://mirror.ghproxy.com/'
TEMP_DIR='/tmp/sing-box'
WORK_DIR='/etc/sing-box'
START_PORT_DEFAULT='8881'
MIN_PORT=1000
MAX_PORT=65520
TLS_SERVER=addons.mozilla.org
CDN_DEFAULT=cn.azhz.eu.org
PROTOCOL_LIST=("XTLS + reality" "hysteria2" "tuic" "shadowTLS" "shadowsocks" "trojan" "vmess + ws" "vless + ws + tls" "H2 + reality" "gRPC + reality")
CONSECUTIVE_PORTS=${#PROTOCOL_LIST[@]}
CDN_DOMAIN=("cn.azhz.eu.org" "www.who.int" "cdn.anycast.eu.org" "443.cf.bestl.de" "cfip.gay")

trap "rm -rf $TEMP_DIR >/dev/null 2>&1 ; echo -e '\n' ;exit 1" INT QUIT TERM EXIT

mkdir -p $TEMP_DIR

E[0]="Language:\n 1. English (default) \n 2. 简体中文"
C[0]="${E[0]}"
E[1]="1. XTLS + REALITY remove flow: xtls-reality-vision to support multiplexing and TCP brutal (requires reinstallation); 2. Clash meta add multiplexing parameter."
C[1]="1. XTLS + REALITY 去掉 xtls-reality-vision 流控以支持多路复用和 TCP brutal (需要重新安装); 2. Clash meta 增加多路复用参数"
E[2]="This project is designed to add sing-box support for multiple protocols to VPS, details: [https://github.com/fscarmen/sing-box]\n Script Features:\n\t • Deploy multiple protocols with one click, there is always one for you!\n\t • Custom ports for nat machine with limited open ports.\n\t • Built-in warp chained proxy to unlock chatGPT.\n\t • No domain name is required.\n\t • Support system: Ubuntu, Debian, CentOS, Alpine and Arch Linux 3.\n\t • Support architecture: AMD,ARM and s390x\n"
C[2]="本项目专为 VPS 添加 sing-box 支持的多种协议, 详细说明: [https://github.com/fscarmen/sing-box]\n 脚本特点:\n\t • 一键部署多协议，总有一款适合你\n\t • 自定义端口，适合有限开放端口的 nat 小鸡\n\t • 内置 warp 链式代理解锁 chatGPT\n\t • 不需要域名\n\t • 智能判断操作系统: Ubuntu 、Debian 、CentOS 、Alpine 和 Arch Linux,请务必选择 LTS 系统\n\t • 支持硬件结构类型: AMD 和 ARM\n"
E[3]="Input errors up to 5 times.The script is aborted."
C[3]="输入错误达5次,脚本退出"
E[4]="UUID should be 36 characters, please re-enter \(\${UUID_ERROR_TIME} times remaining\):"
C[4]="UUID 应为36位字符,请重新输入 \(剩余\${UUID_ERROR_TIME}次\):"
E[5]="The script supports Debian, Ubuntu, CentOS, Alpine, Fedora or Arch systems only. Feedback: [https://github.com/fscarmen/sing-box/issues]"
C[5]="本脚本只支持 Debian、Ubuntu、CentOS、Alpine、Fedora 或 Arch 系统,问题反馈:[https://github.com/fscarmen/sing-box/issues]"
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
E[29]="View links (sb -n)"
C[29]="查看节点信息 (sb -n)"
E[30]="Change listen ports (sb -p)"
C[30]="更换监听端口 (sb -p)"
E[31]="Sync Sing-box to the latest version (sb -v)"
C[31]="同步 Sing-box 至最新版本 (sb -v)"
E[32]="Upgrade kernel, turn on BBR, change Linux system (sb -b)"
C[32]="升级内核、安装BBR、DD脚本 (sb -b)"
E[33]="Uninstall (sb -u)"
C[33]="卸载 (sb -u)"
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
E[46]="Warp / warp-go was detected to be running. Please enter the correct server IP:"
C[46]="检测到 warp / warp-go 正在运行，请输入确认的服务器 IP:"
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
E[54]="The contents of the \$V2RAYN_PROTOCOL configuration file need to be updated for the \$V2RAYN_KERNEL kernel."
C[54]="\$V2RAYN_PROTOCOL 配置文件内容，需要更新 \$V2RAYN_KERNEL 内核"
E[55]="The script runs today: \$TODAY. Total: \$TOTAL"
C[55]="脚本当天运行次数: \$TODAY，累计运行次数: \$TOTAL"
E[56]="Process ID"
C[56]="进程ID"
E[57]="Runtime"
C[57]="运行时长"
E[58]="Memory Usage"
C[58]="内存占用"
E[59]="Install ArgoX scripts (argo + xray) [https://github.com/fscarmen/argox]"
C[59]="安装 ArgoX 脚本 (argo + xray) [https://github.com/fscarmen/argox]"
E[60]="The order of the selected protocols and ports is as follows:"
C[60]="选择的协议及端口次序如下:"
E[61]="(DNS your own domain in Cloudflare is required.)"
C[61]="(必须在 Cloudflare 解析自有域名)"
E[62]="Add / Remove protocols (sb -r)"
C[62]="增加 / 删除协议 (sb -r)"
E[63]="(1/3) Installed protocols."
C[63]="(1/3) 已安装的协议"
E[64]="Please select the protocols to be removed (multiple selections possible):"
C[64]="请选择需要删除的协议（可以多选）:"
E[65]="(2/3) Uninstalled protocols."
C[65]="(2/3) 未安装的协议"
E[66]="Please select the protocols to be added (multiple choices possible):"
C[66]="请选择需要增加的协议（可以多选）:"
E[67]="(3/3) Confirm all protocols for reloading."
C[67]="(3/3) 确认重装的所有协议"
E[68]="Press [n] if there is an error, other keys to continue:"
C[68]="如有错误请按 [n]，其他键继续:"
E[69]="Install sba scripts (argo + sing-box) [https://github.com/fscarmen/sba]"
C[69]="安装 sba 脚本 (argo + sing-box) [https://github.com/fscarmen/sba]"
E[70]="Please set inSecure in tls to true."
C[70]="请把 tls 里的 inSecure 设置为 true"
E[71]="Create shortcut [ sb ] successfully."
C[71]="创建快捷 [ sb ] 指令成功!"
E[72]="The full template can be found at: https://t.me/ztvps/37"
C[72]="完整模板可参照: https://t.me/ztvps/37"
E[73]="There is no protocol left, if you are sure please re-run [ sb -u ] to uninstall all."
C[73]="没有协议剩下，如确定请重新执行 [ sb -u ] 卸载所有"
E[74]="Keep protocols"
C[74]="保留协议"
E[75]="Add protocols"
C[75]="新增协议"
E[76]="Install TCP brutal"
C[76]="安装 TCP brutal"

# 自定义字体彩色，read 函数
warning() { echo -e "\033[31m\033[01m$*\033[0m"; }  # 红色
error() { echo -e "\033[31m\033[01m$*\033[0m" && exit 1; } # 红色
info() { echo -e "\033[32m\033[01m$*\033[0m"; }   # 绿色
hint() { echo -e "\033[33m\033[01m$*\033[0m"; }   # 黄色
reading() { read -rp "$(info "$1")" "$2"; }
text() { grep -q '\$' <<< "${E[$*]}" && eval echo "\$(eval echo "\${${L}[$*]}")" || eval echo "\${${L}[$*]}"; }

# 自定义友道或谷歌翻译函数
translate() {
  [ -n "$@" ] && EN="$@"
  ZH=$(wget --no-check-certificate -qO- --tries=1 --timeout=2 "https://translate.google.com/translate_a/t?client=any_client_id_works&sl=en&tl=zh&q=${EN//[[:space:]]/}")
  [[ "$ZH" =~ ^\[\".+\"\]$ ]] && cut -d \" -f2 <<< "$ZH"
}

# 脚本当天及累计运行次数统计
statistics_of_run-times() {
  local COUNT=$(wget --no-check-certificate -qO- --tries=2 --timeout=2 "https://hits.seeyoufarm.com/api/count/incr/badge.svg?url=https%3A%2F%2Fraw.githubusercontent.com%2Ffscarmen%2Fsing-box%2Fmain%2Fsing-box.sh" 2>&1 | grep -m1 -oE "[0-9]+[ ]+/[ ]+[0-9]+") &&
  TODAY=$(cut -d " " -f1 <<< "$COUNT") &&
  TOTAL=$(cut -d " " -f3 <<< "$COUNT")
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

input_cdn() {
  # 提供网上热心网友的anycast域名
  if [[ -z "$CDN" && -n "$VMESS_HOST_DOMAIN$VLESS_HOST_DOMAIN" ]]; then
    echo ""
    for c in "${!CDN_DOMAIN[@]}"; do hint " $[c+1]. ${CDN_DOMAIN[c]} "; done

    reading "\n $(text 53) " CUSTOM_CDN
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
}

check_root() {
  [ "$(id -u)" != 0 ] && error "\n $(text 43) \n"
}

check_arch() {
  # 判断处理器架构
  case $(uname -m) in
    aarch64|arm64 ) SING_BOX_ARCH=arm64 ;;
    x86_64|amd64 ) [[ "$(awk -F ':' '/flags/{print $2; exit}' /proc/cpuinfo)" =~ avx2 ]] && SING_BOX_ARCH=amd64v3 || SING_BOX_ARCH=amd64 ;;
    armv7l ) SING_BOX_ARCH=armv7 ;;
    * ) error " $(text 25) "
  esac
}

# 查安装及运行状态；状态码: 26 未安装， 27 已安装未运行， 28 运行中
check_install() {
  STATUS=$(text 26) && [ -s /etc/systemd/system/sing-box.service ] && STATUS=$(text 27) && [ "$(systemctl is-active sing-box)" = 'active' ] && STATUS=$(text 28)
  if [[ $STATUS = "$(text 26)" ]] && [ ! -s $WORK_DIR/sing-box ]; then
    {
    local ONLINE=$(wget --no-check-certificate -qO- "https://api.github.com/repos/SagerNet/sing-box/releases" | awk -F '["v]' '/tag_name.*beta/{print $5; exit}')
    ONLINE=${ONLINE:-'1.7.0-beta.5'}
    wget --no-check-certificate -c ${GH_PROXY}https://github.com/SagerNet/sing-box/releases/download/v$ONLINE/sing-box-$ONLINE-linux-$SING_BOX_ARCH.tar.gz -qO- | tar xz -C $TEMP_DIR sing-box-$ONLINE-linux-$SING_BOX_ARCH/sing-box
    [ -s $TEMP_DIR/sing-box-$ONLINE-linux-$SING_BOX_ARCH/sing-box ] && mv $TEMP_DIR/sing-box-$ONLINE-linux-$SING_BOX_ARCH/sing-box $TEMP_DIR
    }&
  fi
}

# 检测 sing-box 的状态
check_sing-box_stats(){
  case "$STATUS" in
    "$(text 26)" )
      error "\n Sing-box $(text 28) $(text 38) \n"
      ;;
    "$(text 27)" )
      cmd_systemctl enable sing-box && info "\n Sing-box $(text 28) $(text 37) \n" || error "\n Sing-box $(text 28) $(text 38) \n"
      ;;
    "$(text 28)" )
      info "\n Sing-box $(text 28) $(text 37) \n"
  esac
}

# 为了适配 alpine，定义 cmd_systemctl 的函数
cmd_systemctl() {
  local ENABLE_DISABLE=$1
  local APP=$2
  if [ "$ENABLE_DISABLE" = 'enable' ]; then
    if [ "$SYSTEM" = 'Alpine' ]; then
      systemctl start $APP
      cat > /etc/local.d/$APP.start << EOF
#!/usr/bin/env bash

systemctl start $APP
EOF
      chmod +x /etc/local.d/$APP.start
      rc-update add local >/dev/null 2>&1
    else
      systemctl enable --now $APP
    fi

  elif [ "$ENABLE_DISABLE" = 'disable' ]; then
    if [ "$SYSTEM" = 'Alpine' ]; then
      systemctl stop $APP
      rm -f /etc/local.d/$APP.start
    else
      systemctl disable --now $APP
    fi
  fi
}

check_system_info() {
  # 判断虚拟化
  if [ $(type -p systemd-detect-virt) ]; then
    VIRT=$(systemd-detect-virt)
  elif [ $(type -p hostnamectl) ]; then
    VIRT=$(hostnamectl | awk '/Virtualization/{print $NF}')
  elif [ $(type -p virt-what) ]; then
    VIRT=$(virt-what)
  fi

  [ -s /etc/os-release ] && SYS="$(grep -i pretty_name /etc/os-release | cut -d \" -f2)"
  [[ -z "$SYS" && $(type -p hostnamectl) ]] && SYS="$(hostnamectl | grep -i system | cut -d : -f2)"
  [[ -z "$SYS" && $(type -p lsb_release) ]] && SYS="$(lsb_release -sd)"
  [[ -z "$SYS" && -s /etc/lsb-release ]] && SYS="$(grep -i description /etc/lsb-release | cut -d \" -f2)"
  [[ -z "$SYS" && -s /etc/redhat-release ]] && SYS="$(grep . /etc/redhat-release)"
  [[ -z "$SYS" && -s /etc/issue ]] && SYS="$(grep . /etc/issue | cut -d '\' -f1 | sed '/^[ ]*$/d')"

  REGEX=("debian" "ubuntu" "centos|red hat|kernel|oracle linux|alma|rocky" "amazon linux" "arch linux" "alpine" "fedora")
  RELEASE=("Debian" "Ubuntu" "CentOS" "CentOS" "Arch" "Alpine" "Fedora")
  EXCLUDE=("")
  MAJOR=("9" "16" "7" "7" "3" "" "37")
  PACKAGE_UPDATE=("apt -y update" "apt -y update" "yum -y update" "yum -y update" "pacman -Sy" "apk update -f" "dnf -y update")
  PACKAGE_INSTALL=("apt -y install" "apt -y install" "yum -y install" "yum -y install" "pacman -S --noconfirm" "apk add --no-cache" "dnf -y install")
  PACKAGE_UNINSTALL=("apt -y autoremove" "apt -y autoremove" "yum -y autoremove" "yum -y autoremove" "pacman -Rcnsu --noconfirm" "apk del -f" "dnf -y autoremove")

  for int in "${!REGEX[@]}"; do [[ $(tr 'A-Z' 'a-z' <<< "$SYS") =~ ${REGEX[int]} ]] && SYSTEM="${RELEASE[int]}" && break; done
  [ -z "$SYSTEM" ] && error " $(text 5) "

  # 先排除 EXCLUDE 里包括的特定系统，其他系统需要作大发行版本的比较
  for ex in "${EXCLUDE[@]}"; do [[ ! $(tr 'A-Z' 'a-z' <<< "$SYS")  =~ $ex ]]; done &&
  [[ "$(echo "$SYS" | sed "s/[^0-9.]//g" | cut -d. -f1)" -lt "${MAJOR[int]}" ]] && error " $(text 6) "
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
      [ -z "$START_PORT" ] && reading "\n $(text 11) " START_PORT
    fi
    START_PORT=${START_PORT:-"$START_PORT_DEFAULT"}
    if [[ "$START_PORT" =~ ^[1-9][0-9]{3,4}$ && "$START_PORT" -ge "$MIN_PORT" && "$START_PORT" -le "$MAX_PORT" ]]; then
      for port in $(eval echo {$START_PORT..$[START_PORT+NUM-1]}); do
        if [ "$SYSTEM" = 'Alpine' ]; then
          netstat -an | awk '/:[0-9]+/{print $4}' | awk -F ":" '{print $NF}' | grep -q $port && IN_USED+=("$port")
        else
          lsof -i:$port >/dev/null 2>&1 && IN_USED+=("$port")
        fi
      done
      [ "${#IN_USED[*]}" -eq 0 ] && break || warning "\n $(text 44) \n"
    fi
  done
}

# 定义 Sing-box 变量
sing-box_variable() {
  if grep -qi 'cloudflare' <<< "$ASNORG4$ASNORG6"; then
    local a=6
    until [ -n "$SERVER_IP" ]; do
      ((a--)) || true
      [ "$a" = 0 ] && error "\n $(text 3) \n"
      reading "\n $(text 46) " SERVER_IP
    done
    if [[ "$SERVER_IP" =~ : ]]; then
      WARP_ENDPOINT=2606:4700:d0::a29f:c101
      DOMAIN_STRATEG=prefer_ipv6
    else
      WARP_ENDPOINT=162.159.193.10
      DOMAIN_STRATEG=prefer_ipv4
    fi
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
  MAX_CHOOSE_PROTOCOLS=$(asc $[CONSECUTIVE_PORTS+96+1])
  if [ -z "$CHOOSE_PROTOCOLS" ]; then
    hint "\n $(text 49) "
    for e in "${!PROTOCOL_LIST[@]}"; do
      [[ "$e" =~ '6'|'7' ]] && hint " $(asc $[e+98]). ${PROTOCOL_LIST[e]} $(text 61) " || hint " $(asc $[e+98]). ${PROTOCOL_LIST[e]} "
    done
    reading "\n $(text 24) " CHOOSE_PROTOCOLS
  fi

  # 对选择协议的输入处理逻辑：先把所有的大写转为小写，并把所有没有去选项剔除掉，最后按输入的次序排序。如果选项为 a(all) 和其他选项并存，将会忽略 a，如 abc 则会处理为 bc
  CHOOSE_PROTOCOLS=$(tr '[:upper:]' '[:lower:]' <<< "$CHOOSE_PROTOCOLS")
  [[ ! "$CHOOSE_PROTOCOLS" =~ [b-$MAX_CHOOSE_PROTOCOLS] ]] && INSTALL_PROTOCOLS=($(eval echo {b..$MAX_CHOOSE_PROTOCOLS})) || INSTALL_PROTOCOLS=($(grep -o . <<< "$CHOOSE_PROTOCOLS" | sed "/[^b-$MAX_CHOOSE_PROTOCOLS]/d" | awk '!seen[$0]++'))

  # 显示选择协议及其次序，输入开始端口号
  if [ -z "$START_PORT" ]; then
    hint "\n $(text 60) "
    for d in "${!INSTALL_PROTOCOLS[@]}"; do
      [ "$d" -ge 9 ] && hint " $[d+1]. ${PROTOCOL_LIST[$(($(asc ${INSTALL_PROTOCOLS[d]}) - 98))]} " || hint " $[d+1] . ${PROTOCOL_LIST[$(($(asc ${INSTALL_PROTOCOLS[d]}) - 98))]} "
    done
    enter_start_port ${#INSTALL_PROTOCOLS[@]}
  fi

  # 输入服务器 IP,默认为检测到的服务器 IP，如果全部为空，则提示并退出脚本
  [ -z "$SERVER_IP" ] && reading "\n $(text 10) " SERVER_IP
  SERVER_IP=${SERVER_IP:-"$SERVER_IP_DEFAULT"} && WS_SERVER_IP=$SERVER_IP
  [ -z "$SERVER_IP" ] && error " $(text 47) "

  # 如选择有 h. vmess + ws 或 i. vless + ws 时，先检测是否有支持的 http 端口可用，如有则要求输入域名和 cdn
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ 'h' ]]; then
    local DOMAIN_ERROR_TIME=5
    until [ -n "$VMESS_HOST_DOMAIN" ]; do
      (( DOMAIN_ERROR_TIME-- )) || true
      [ "$DOMAIN_ERROR_TIME" != 0 ] && TYPE=VMESS && reading "\n $(text 50) " VMESS_HOST_DOMAIN || error "\n $(text 3) \n"
    done
  fi

  if [[ "${INSTALL_PROTOCOLS[@]}" =~ 'i' ]]; then
    local DOMAIN_ERROR_TIME=5
    until [ -n "$VLESS_HOST_DOMAIN" ]; do
      (( DOMAIN_ERROR_TIME-- )) || true
      [ "$DOMAIN_ERROR_TIME" != 0 ] && TYPE=VLESS && reading "\n $(text 50) " VLESS_HOST_DOMAIN || error "\n $(text 3) \n"
    done
  fi

  # 选择或者输入 cdn
  input_cdn

  wait

  # 输入 UUID ，错误超过 5 次将会退出
  UUID_DEFAULT=$($TEMP_DIR/sing-box generate uuid)
  [ -z "$UUID" ] && reading "\n $(text 12) " UUID
  local UUID_ERROR_TIME=5
  until [[ -z "$UUID" || "$UUID" =~ ^[A-F0-9a-f]{8}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{12}$ ]]; do
    (( UUID_ERROR_TIME-- )) || true
    [ "$UUID_ERROR_TIME" = 0 ] && error "\n $(text 3) \n" || reading "\n $(text 4) \n" UUID
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
  reading "\n $(text 13) " NODE_NAME
  NODE_NAME="${NODE_NAME:-"$NODE_NAME_DEFAULT"}"
}

check_dependencies() {
  # 如果是 Alpine，先升级 wget ，安装 systemctl-py 版
  if [ "$SYSTEM" = 'Alpine' ]; then
    CHECK_WGET=$(wget 2>&1 | head -n 1)
    grep -qi 'busybox' <<< "$CHECK_WGET" && ${PACKAGE_INSTALL[int]} wget >/dev/null 2>&1

    DEPS_CHECK=("bash" "python3" "rc-update" "openssl" "virt-what")
    DEPS_INSTALL=("bash" "python3" "openrc" "openssl" "virt-what")
    for g in "${!DEPS_CHECK[@]}"; do [ ! $(type -p ${DEPS_CHECK[g]}) ] && [[ ! "${DEPS[@]}" =~ "${DEPS_INSTALL[g]}" ]] && DEPS+=(${DEPS_INSTALL[g]}); done
    if [ "${#DEPS[@]}" -ge 1 ]; then
      info "\n $(text 7) ${DEPS[@]} \n"
      ${PACKAGE_UPDATE[int]} >/dev/null 2>&1
      ${PACKAGE_INSTALL[int]} ${DEPS[@]} >/dev/null 2>&1
    fi

    [ ! $(type -p systemctl) ] && wget --no-check-certificate https://raw.githubusercontent.com/gdraheim/docker-systemctl-replacement/master/files/docker/systemctl3.py -O /bin/systemctl && chmod a+x /bin/systemctl
  fi

  # 检测 Linux 系统的依赖，升级库并重新安装依赖
  unset DEPS_CHECK DEPS_INSTALL DEPS
  DEPS_CHECK=("wget" "systemctl" "ip" "unzip" "lsof" "bash" "openssl")
  DEPS_INSTALL=("wget" "systemctl" "iproute2" "unzip" "lsof" "bash" "openssl")
  for g in "${!DEPS_CHECK[@]}"; do [ ! $(type -p ${DEPS_CHECK[g]}) ] && [[ ! "${DEPS[@]}" =~ "${DEPS_INSTALL[g]}" ]] && DEPS+=(${DEPS_INSTALL[g]}); done
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
  local IS_CHANGE=$1
  mkdir -p $WORK_DIR/conf $WORK_DIR/logs

  # 生成 dns 配置
  [ "$IS_CHANGE" != 'change' ] && cat > $WORK_DIR/conf/00_log.json << EOF
{
    "log":{
        "disabled":false,
        "level":"error",
        "output":"$WORK_DIR/logs/box.log",
        "timestamp":true
    }
}
EOF
  # 生成 outbound 配置
  [ "$IS_CHANGE" != 'change' ] && cat > $WORK_DIR/conf/01_outbounds.json << EOF
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

  # 生成 route 配置
  [ "$IS_CHANGE" != 'change' ] && cat > $WORK_DIR/conf/02_route.json << EOF
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

  # 第1个协议为 b  (a为全部)，生成 XTLS + Reality 配置
  CHECK_PROTOCOLS=b
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    [[ -z "$REALITY_PRIVATE" || -z "$REALITY_PUBLIC" ]] && REALITY_KEYPAIR=$($TEMP_DIR/sing-box generate reality-keypair)
    [ -z "$REALITY_PRIVATE" ] && REALITY_PRIVATE=$(awk '/PrivateKey/{print $NF}' <<< "$REALITY_KEYPAIR")
    [ -z "$REALITY_PUBLIC" ] && REALITY_PUBLIC=$(awk '/PublicKey/{print $NF}' <<< "$REALITY_KEYPAIR")
    [ -z "$PORT_XTLS_REALITY" ] && PORT_XTLS_REALITY=$[START_PORT+$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")]
    cat > $WORK_DIR/conf/11_XTLS_REALITY_inbounds.json << EOF
{
    "inbounds":[
        {
            "type":"vless",
            "sniff":true,
            "sniff_override_destination":true,
            "tag":"xtls-reality-in",
            "listen":"::",
            "listen_port":$PORT_XTLS_REALITY,
            "users":[
                {
                    "uuid":"$UUID",
                    "flow":""
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
            },
            "multiplex":{
                "enabled":true,
                "padding":true,
                "brutal":{
                    "enabled":true,
                    "up_mbps":1000,
                    "down_mbps":1000
                }
            }
        }
    ]
}
EOF
  fi

  # 生成 Hysteria2 配置
  CHECK_PROTOCOLS=$(asc "$CHECK_PROTOCOLS" ++)
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    [ -z "$PORT_HYSTERIA2" ] && PORT_HYSTERIA2=$[START_PORT+$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")]
    cat > $WORK_DIR/conf/12_HYSTERIA2_inbounds.json << EOF
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

  # 生成 Tuic V5 配置
  CHECK_PROTOCOLS=$(asc "$CHECK_PROTOCOLS" ++)
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    [ -z "$PORT_TUIC" ] && PORT_TUIC=$[START_PORT+$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")]
    cat > $WORK_DIR/conf/13_TUIC_inbounds.json << EOF
{
    "inbounds":[
        {
            "type":"tuic",
            "sniff":true,
            "tag":"tuic-in",
            "sniff_override_destination":true,
            "listen":"::",
            "listen_port":$PORT_TUIC,
            "users":[
                {
                    "uuid":"$UUID",
                    "password":"$UUID"
                }
            ],
            "congestion_control": "bbr",
            "zero_rtt_handshake": false,
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

  # 生成 shadowTLS V5 配置
  CHECK_PROTOCOLS=$(asc "$CHECK_PROTOCOLS" ++)
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    [ -z "$SHADOWTLS_PASSWORD" ] && SHADOWTLS_PASSWORD=$($TEMP_DIR/sing-box generate rand --base64 16)
    [ -z "$PORT_SHADOWTLS" ] && PORT_SHADOWTLS=$[START_PORT+$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")]
    cat > $WORK_DIR/conf/14_SHADOWTLS_inbounds.json << EOF
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
            "password":"$SHADOWTLS_PASSWORD",
            "multiplex":{
                "enabled":true,
                "padding":true,
                "brutal":{
                    "enabled":true,
                    "up_mbps":1000,
                    "down_mbps":1000
                }
            }
        }
    ]
}
EOF
  fi

  # 生成 Shadowsocks 配置
  CHECK_PROTOCOLS=$(asc "$CHECK_PROTOCOLS" ++)
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    [ -z "$PORT_SHADOWSOCKS" ] && PORT_SHADOWSOCKS=$[START_PORT+$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")]
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
            "password":"$UUID",
            "multiplex":{
                "enabled":true,
                "padding":true,
                "brutal":{
                    "enabled":true,
                    "up_mbps":1000,
                    "down_mbps":1000
                }
            }
        }
    ]
}
EOF
  fi

  # 生成 Trojan 配置
  CHECK_PROTOCOLS=$(asc "$CHECK_PROTOCOLS" ++)
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    [ -z "$PORT_TROJAN" ] && PORT_TROJAN=$[START_PORT+$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")]
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
            },
            "multiplex":{
                "enabled":true,
                "padding":true,
                "brutal":{
                    "enabled":true,
                    "up_mbps":1000,
                    "down_mbps":1000
                }
            }
        }
    ]
}
EOF
  fi

  # 生成 vmess + ws 配置
  CHECK_PROTOCOLS=$(asc "$CHECK_PROTOCOLS" ++)
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    [ -z "$PORT_VMESS_WS" ] && PORT_VMESS_WS=$[START_PORT+$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")]
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
            },
            "multiplex":{
                "enabled":true,
                "padding":true,
                "brutal":{
                    "enabled":true,
                    "up_mbps":1000,
                    "down_mbps":1000
                }
            }
        }
    ]
}
EOF
  fi

  # 生成 vless + ws + tls 配置
  CHECK_PROTOCOLS=$(asc "$CHECK_PROTOCOLS" ++)
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    [ -z "$PORT_VLESS_WS" ] && PORT_VLESS_WS=$[START_PORT+$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")]
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
                "certificate_path":"${WORK_DIR}/cert/cert.pem",
                "key_path":"${WORK_DIR}/cert/private.key"
            },
            "multiplex":{
                "enabled":true,
                "padding":true,
                "brutal":{
                    "enabled":true,
                    "up_mbps":1000,
                    "down_mbps":1000
                }
            }
        }
    ]
}
EOF
  fi

  # 生成 H2 + Reality 配置
  CHECK_PROTOCOLS=$(asc "$CHECK_PROTOCOLS" ++)
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    [[ -z "$REALITY_PRIVATE" || -z "$REALITY_PUBLIC" ]] && REALITY_KEYPAIR=$($TEMP_DIR/sing-box generate reality-keypair)
    [ -z "$REALITY_PRIVATE" ] && REALITY_PRIVATE=$(awk '/PrivateKey/{print $NF}' <<< "$REALITY_KEYPAIR")
    [ -z "$REALITY_PUBLIC" ] && REALITY_PUBLIC=$(awk '/PublicKey/{print $NF}' <<< "$REALITY_KEYPAIR")
    [ -z "$PORT_H2_REALITY" ] && PORT_H2_REALITY=$[START_PORT+$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")]
    cat > $WORK_DIR/conf/19_H2_REALITY_inbounds.json << EOF
{
    "inbounds":[
        {
            "type":"vless",
            "sniff":true,
            "sniff_override_destination":true,
            "tag":"h2-reality-in",
            "listen":"::",
            "listen_port":$PORT_H2_REALITY,
            "users":[
                {
                    "uuid":"$UUID"
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
            },
            "transport": {
                "type": "http"
            },
            "multiplex":{
                "enabled":true,
                "padding":true,
                "brutal":{
                    "enabled":true,
                    "up_mbps":1000,
                    "down_mbps":1000
                }
            }
        }
    ]
}
EOF
  fi

  # 生成 gRPC + Reality 配置
  CHECK_PROTOCOLS=$(asc "$CHECK_PROTOCOLS" ++)
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    [[ -z "$REALITY_PRIVATE" || -z "$REALITY_PUBLIC" ]] && REALITY_KEYPAIR=$($TEMP_DIR/sing-box generate reality-keypair)
    [ -z "$REALITY_PRIVATE" ] && REALITY_PRIVATE=$(awk '/PrivateKey/{print $NF}' <<< "$REALITY_KEYPAIR")
    [ -z "$REALITY_PUBLIC" ] && REALITY_PUBLIC=$(awk '/PublicKey/{print $NF}' <<< "$REALITY_KEYPAIR")
    [ -z "$PORT_GRPC_REALITY" ] && PORT_GRPC_REALITY=$[START_PORT+$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")]
    cat > $WORK_DIR/conf/20_GRPC_REALITY_inbounds.json << EOF
{
    "inbounds":[
        {
            "type":"vless",
            "sniff":true,
            "sniff_override_destination":true,
            "tag":"grpc-reality-in",
            "listen":"::",
            "listen_port":$PORT_GRPC_REALITY,
            "users":[
                {
                    "uuid":"$UUID"
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
            },
            "transport": {
                "type": "grpc",
                "service_name": "grpc"
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

  # 如果 Alpine 系统，放到开机自启动
  if [ "$SYSTEM" = 'Alpine' ]; then
    cat > /etc/local.d/sing-box.start << EOF
#!/usr/bin/env bash

systemctl start sing-box
EOF
    chmod +x /etc/local.d/sing-box.start
    rc-update add local >/dev/null 2>&1
  fi

  # 再次检测状态，运行 Sing-box
  check_install

  check_sing-box_stats
}

export_list() {
  check_install
  if [ -s $WORK_DIR/list ]; then
    SERVER_IP=${SERVER_IP:-"$(sed -r "s/\x1B\[[0-9;]*[mG]//g" $WORK_DIR/list | sed -n "s/.*{name.*server:[ ]*\([^,]\+\).*/\1/pg" | sed -n '1p')"}
    UUID=${UUID:-"$(sed -r "s/\x1B\[[0-9;]*[mG]//g" $WORK_DIR/list | grep -m1 '{name' | sed -En 's/.*password:[ ]+[\"]*|.*uuid:[ ]+[\"]*(.*)/\1/gp' | sed "s/\([^,\"]\+\).*/\1/g")"}
    SHADOWTLS_PASSWORD=${SHADOWTLS_PASSWORD:-"$(sed -r "s/\x1B\[[0-9;]*[mG]//g" $WORK_DIR/list | sed -n 's/.*{name.*password:[ ]*\"\([^\"]\+\)".*shadow-tls.*/\1/pg')"}
    TLS_SERVER=${TLS_SERVER:-"$(sed -r "s/\x1B\[[0-9;]*[mG]//g" $WORK_DIR/list | grep -Em1 '\{name.*shadow-tls|\{name.*public-key' | sed -n "s/.*servername:[ ]\+\([^\,]\+\).*/\1/gp; s/.*host:[ ]\+\"\([^\"]\+\).*/\1/gp")"}
    NODE_NAME=${NODE_NAME:-"$(sed -r "s/\x1B\[[0-9;]*[mG]//g" $WORK_DIR/list | grep -m1 '{name' | sed 's/- {name:[ ]\+"//; s/[ ]\+ShadowTLS[ ]\+v3.*//; s/[ ]\+xtls-reality.*//; s/[ ]\+hysteria2.*//; s/[ ]\+tuic.*//; s/[ ]\+ss.*//; s/[ ]\+trojan.*//; s/[ ]\+trojan.*//; s/[ ]\+vmess[ ]\+ws.*//; s/[ ]\+vless[ ]\+.*//')"}
    REALITY_PUBLIC=${REALITY_PUBLIC:-"$(sed -n 's/.*{name.*public-key:[ ]*\([^,]\+\).*/\1/pg' $WORK_DIR/list | sed -n 1p)"}
    [ -s $WORK_DIR/conf/*_XTLS_REALITY_inbounds.json ] && PORT_XTLS_REALITY=$(sed -n '/listen_port/s/[^0-9]\+//gp' $WORK_DIR/conf/*_XTLS_REALITY_inbounds.json)
    [ -s $WORK_DIR/conf/*_HYSTERIA2_inbounds.json ] && PORT_HYSTERIA2=$(sed -n '/listen_port/s/[^0-9]\+//gp' $WORK_DIR/conf/*_HYSTERIA2_inbounds.json)
    [ -s $WORK_DIR/conf/*_TUIC_inbounds.json ] && PORT_TUIC=$(sed -n '/listen_port/s/[^0-9]\+//gp' $WORK_DIR/conf/*_TUIC_inbounds.json)
    [ -s $WORK_DIR/conf/*_SHADOWTLS_inbounds.json ] && PORT_SHADOWTLS=$(sed -n '/listen_port/s/[^0-9]\+//gp' $WORK_DIR/conf/*_SHADOWTLS_inbounds.json)
    [ -s $WORK_DIR/conf/*_SHADOWSOCKS_inbounds.json ] && PORT_SHADOWSOCKS=$(sed -n '/listen_port/s/[^0-9]\+//gp' $WORK_DIR/conf/*_SHADOWSOCKS_inbounds.json)
    [ -s $WORK_DIR/conf/*_TROJAN_inbounds.json ] && PORT_TROJAN=$(sed -n '/listen_port/s/[^0-9]\+//gp' $WORK_DIR/conf/*_TROJAN_inbounds.json)
    [ -s $WORK_DIR/conf/*_VMESS_WS_inbounds.json ] && WS_SERVER_IP=${WS_SERVER_IP:-"$(grep -A2 "{name.*vmess[ ]\+ws" $WORK_DIR/list | awk -F'[][]' 'NR==3 {print $2}')"} && VMESS_HOST_DOMAIN=${VMESS_HOST_DOMAIN:-"$(grep -A2 "{name.*vmess[ ]\+ws" $WORK_DIR/list | awk -F'[][]' 'NR==3 {print $4}')"} && PORT_VMESS_WS=${PORT_VMESS_WS:-"$(sed -n '/listen_port/s/[^0-9]\+//gp' $WORK_DIR/conf/*_VMESS_WS_inbounds.json)"} && CDN=${CDN:-"$(sed -n "s/.*{name.*vmess[ ]\+ws.*server:[ ]\+\([^,]\+\).*/\1/gp" $WORK_DIR/list)"}
    [ -s $WORK_DIR/conf/*_VLESS_WS_inbounds.json ] && WS_SERVER_IP=${WS_SERVER_IP:-"$(grep -A2 "{name.*vless[ ]\+ws" $WORK_DIR/list | awk -F'[][]' 'NR==3 {print $2}')"} && VLESS_HOST_DOMAIN=${VLESS_HOST_DOMAIN:-"$(grep -A2 "{name.*vless[ ]\+ws" $WORK_DIR/list | awk -F'[][]' 'NR==3 {print $4}')"} && PORT_VLESS_WS=${PORT_VLESS_WS:-"$(sed -n '/listen_port/s/[^0-9]\+//gp' $WORK_DIR/conf/*_VLESS_WS_inbounds.json)"} && CDN=${CDN:-"$(sed -n "s/.*{name.*vless[ ]\+ws.*server:[ ]\+\([^,]\+\).*/\1/gp" $WORK_DIR/list)"}
    [ -s $WORK_DIR/conf/*_H2_REALITY_inbounds.json ] && PORT_H2_REALITY=$(sed -n '/listen_port/s/[^0-9]\+//gp' $WORK_DIR/conf/*_H2_REALITY_inbounds.json)
    [ -s $WORK_DIR/conf/*_GRPC_REALITY_inbounds.json ] && PORT_GRPC_REALITY=$(sed -n '/listen_port/s/[^0-9]\+//gp' $WORK_DIR/conf/*_GRPC_REALITY_inbounds.json)
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
  [ -n "$PORT_XTLS_REALITY" ] && cat >> $WORK_DIR/list << EOF

----------------------------
$(info "vless://${UUID}@${SERVER_IP_1}:${PORT_XTLS_REALITY}?encryption=none&security=reality&sni=${TLS_SERVER}&fp=chrome&pbk=${REALITY_PUBLIC}&type=tcp&headerType=none#${NODE_NAME} xtls-reality")
EOF
  [ -n "$PORT_HYSTERIA2" ] && V2RAYN_PROTOCOL=Hysteria2 && V2RAYN_KERNEL=hysteria2 && cat >> $WORK_DIR/list << EOF

----------------------------
$(info "$(text 54)

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
  [ -n "$PORT_TUIC" ] && V2RAYN_PROTOCOL=Tuic && V2RAYN_KERNEL=sing_box && cat >> $WORK_DIR/list << EOF

----------------------------
$(info "$(text 54)

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
            \"tag\": \"proxy\",
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
  [ -n "$PORT_SHADOWTLS" ] && V2RAYN_PROTOCOL=ShadowTLS && V2RAYN_KERNEL=sing_box && cat >> $WORK_DIR/list << EOF

----------------------------
$(info "$(text 54)

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
          \"tag\": \"ShadowTLS\",
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
          \"udp_over_tcp\": false,
          \"multiplex\": {
            \"enabled\": true,
            \"protocol\": \"h2mux\",
            \"max_connections\": 8,
            \"min_streams\": 16,
            \"padding\": true
          }
      },
      {
          \"domain_strategy\":\"\",
          \"password\":\"${UUID}\",
          \"server\":\"${SERVER_IP}\",
          \"server_port\":${PORT_SHADOWTLS},
          \"tag\": \"shadowtls-out\",
          \"tls\":{
              \"enabled\":true,
              \"server_name\":\"${TLS_SERVER}\",
              \"utls\": {
                \"enabled\": true,
                \"fingerprint\": \"chrome\"
              }
          },
          \"multiplex\":{
            \"enabled\":true,
            \"padding\":true
          },
          \"type\":\"shadowtls\",
          \"version\":3
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

$(text 70)")
EOF
  [ -n "$PORT_VMESS_WS" ] && TYPE_HOST_DOMAIN=$VMESS_HOST_DOMAIN && TYPE_PORT_WS=$PORT_VMESS_WS && cat >> $WORK_DIR/list << EOF

----------------------------
$(info "vmess://$(base64 -w0 <<< "{ \"v\": \"2\", \"ps\": \"${NODE_NAME} vmess ws\", \"add\": \"${CDN}\", \"port\": \"80\", \"id\": \"${UUID}\", \"aid\": \"0\", \"scy\": \"none\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"${VMESS_HOST_DOMAIN}\", \"path\": \"/${UUID}-vmess\", \"tls\": \"\", \"sni\": \"\", \"alpn\": \"\" }" | sed "s/Cg==$//")

$(text 52)")
EOF
  [ -n "$PORT_VLESS_WS" ] && TYPE_HOST_DOMAIN=$VLESS_HOST_DOMAIN && TYPE_PORT_WS=$PORT_VLESS_WS && cat >> $WORK_DIR/list << EOF

----------------------------
$(info "vless://${UUID}@${CDN}:443?encryption=none&security=tls&sni=${VLESS_HOST_DOMAIN}&type=ws&host=${VLESS_HOST_DOMAIN}&path=%2F${UUID}-vless%3Fed%3D2048#${NODE_NAME} vless ws

$(text 52)")
EOF
  [ -n "$PORT_H2_REALITY" ] && cat >> $WORK_DIR/list << EOF

----------------------------
$(info "vless://${UUID}@${SERVER_IP_1}:${PORT_H2_REALITY}?encryption=none&security=reality&sni=${TLS_SERVER}&fp=chrome&pbk=${REALITY_PUBLIC}&type=http#${NODE_NAME} h2-reality-vision")
EOF
  [ -n "$PORT_GRPC_REALITY" ] && cat >> $WORK_DIR/list << EOF

----------------------------
$(info "vless://${UUID}@${SERVER_IP_1}:${PORT_GRPC_REALITY}?encryption=none&security=reality&sni=${TLS_SERVER}&fp=chrome&pbk=${REALITY_PUBLIC}&type=grpc&serviceName=grpc&mode=gun#${NODE_NAME} grpc-reality-vision")
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
  [ -n "$PORT_XTLS_REALITY" ] && cat >> $WORK_DIR/list << EOF

$(hint "vless://$(base64 -w0 <<< auto:$UUID@${SERVER_IP_2}:${PORT_XTLS_REALITY} | sed "s/Cg==$//")?remarks=${NODE_NAME}%20xtls-reality&obfs=none&tls=1&peer=$TLS_SERVER&mux=1&pbk=$REALITY_PUBLIC")
EOF
  [ -n "$PORT_HYSTERIA2" ] && cat >> $WORK_DIR/list << EOF

$(hint "hysteria2://${UUID}@${SERVER_IP_2}:${PORT_HYSTERIA2}?insecure=1&obfs=none&obfs-password=${UUID}#${NODE_NAME}%20hysteria2")
EOF
  [ -n "$PORT_TUIC" ] && cat >> $WORK_DIR/list << EOF

$(hint "tuic://${UUID}:${UUID}@${SERVER_IP_2}:${PORT_TUIC}?congestion_control=bbr&udp_relay_mode=native&alpn=h3&allow_insecure=1#${NODE_NAME}%20tuic")
EOF
  [ -n "$PORT_SHADOWTLS" ] && cat >> $WORK_DIR/list << EOF

$(hint "ss://$(base64 -w0 <<< 2022-blake3-aes-128-gcm:${SHADOWTLS_PASSWORD}@${SERVER_IP_2}:${PORT_SHADOWTLS} | sed "s/Cg==$//")?shadow-tls=$(base64 -w0 <<< {\"version\":\"3\",\"host\":\"$TLS_SERVER\",\"password\":\"$UUID\" | sed "s/Cg==$//")#${NODE_NAME}%20ShadowTLS%20v3")
EOF
  [ -n "$PORT_SHADOWSOCKS" ] && cat >> $WORK_DIR/list << EOF

$(hint "ss://$(base64 -w0 <<< aes-128-gcm:${UUID}@${SERVER_IP_2}:${PORT_SHADOWSOCKS} | sed "s/Cg==$//")#${NODE_NAME}%20ss")
EOF
  [ -n "$PORT_TROJAN" ] && cat >> $WORK_DIR/list << EOF

$(hint "trojan://${UUID}@${SERVER_IP_1}:${PORT_TROJAN}?allowInsecure=1#${NODE_NAME}%20trojan")
EOF
  [ -n "$PORT_VMESS_WS" ] && TYPE_HOST_DOMAIN=$VMESS_HOST_DOMAIN && TYPE_PORT_WS=$PORT_VMESS_WS && cat >> $WORK_DIR/list << EOF

----------------------------
$(hint "vmess://$(base64 -w0 <<< "none:${UUID}@${CDN}:80" | sed "s/Cg==$//")?remarks=${NODE_NAME}%20vmess%20ws&obfsParam=${VMESS_HOST_DOMAIN}&path=/${UUID}-vmess&obfs=websocket&alterId=0

$(text 52)")
EOF
  [ -n "$PORT_VLESS_WS" ] && TYPE_HOST_DOMAIN=$VLESS_HOST_DOMAIN && TYPE_PORT_WS=$PORT_VLESS_WS && cat >> $WORK_DIR/list << EOF

----------------------------
$(hint "vless://$(base64 -w0 <<< "auto:${UUID}@${CDN}:443" | sed "s/Cg==$//")?remarks=${NODE_NAME}%20vless%20ws&obfsParam=${VLESS_HOST_DOMAIN}&path=/${UUID}-vless?ed=2048&obfs=websocket&tls=1&peer=${VLESS_HOST_DOMAIN}&allowInsecure=1

$(text 52)")
EOF
  [ -n "$PORT_H2_REALITY" ] && cat >> $WORK_DIR/list << EOF

----------------------------
$(hint "vless://$(base64 -w0 <<< auto:${UUID}@${SERVER_IP_2}:${PORT_H2_REALITY} | sed "s/Cg==$//")?remarks=${NODE_NAME}%20h2-reality-vision&path=/&obfs=h2&tls=1&peer=${TLS_SERVER}&alpn=h2&mux=1&pbk=${REALITY_PUBLIC}")
EOF
  [ -n "$PORT_GRPC_REALITY" ] && cat >> $WORK_DIR/list << EOF

----------------------------
$(hint "vless://$(base64 -w0 <<< "auto:${UUID}@${SERVER_IP_2}:${PORT_GRPC_REALITY}" | sed "s/Cg==$//")?remarks=${NODE_NAME}%20grpc-reality-vision&path=grpc&obfs=grpc&tls=1&peer=${TLS_SERVER}&pbk=${REALITY_PUBLIC}")
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
  [ -n "$PORT_XTLS_REALITY" ] && cat >> $WORK_DIR/list << EOF

$(info "- {name: \"${NODE_NAME} xtls-reality\", type: vless, server: ${SERVER_IP}, port: ${PORT_XTLS_REALITY}, uuid: ${UUID}, network: tcp, udp: true, tls: true, servername: ${TLS_SERVER}, client-fingerprint: chrome, reality-opts: {public-key: ${REALITY_PUBLIC}, short-id: \"\"}, smux: { enabled: true, protocol: 'h2mux', padding: true, max-connections: '8', min-streams: '16', statistic: true, only-tcp: false } }")
EOF
  [ -n "$PORT_HYSTERIA2" ] && cat >> $WORK_DIR/list << EOF

$(info "- {name: \"${NODE_NAME} hysteria2\", type: hysteria2, server: ${SERVER_IP}, port: ${PORT_HYSTERIA2}, up: \"200 Mbps\", down: \"1000 Mbps\", password: ${UUID}, obfs: salamander, obfs-password: ${UUID}, skip-cert-verify: true}")
EOF
  [ -n "$PORT_TUIC" ] && cat >> $WORK_DIR/list << EOF

$(info "- {name: \"${NODE_NAME} tuic\", type: tuic, server: ${SERVER_IP}, port: ${PORT_TUIC}, uuid: ${UUID}, password: ${UUID}, alpn: [h3], disable-sni: true, reduce-rtt: true, request-timeout: 8000, udp-relay-mode: native, congestion-controller: bbr, skip-cert-verify: true}")
EOF
  [ -n "$PORT_SHADOWTLS" ] && cat >> $WORK_DIR/list << EOF

$(info "- {name: \"${NODE_NAME} ShadowTLS v3\", type: ss, server: ${SERVER_IP}, port: ${PORT_SHADOWTLS}, cipher: 2022-blake3-aes-128-gcm, password: \"${SHADOWTLS_PASSWORD}\", plugin: shadow-tls, client-fingerprint: chrome, plugin-opts: {host: \"${TLS_SERVER}\", password: \"${UUID}\", version: 3}, smux: { enabled: true, protocol: 'h2mux', padding: true, max-connections: '8', min-streams: '16', statistic: true, only-tcp: false } }")
EOF
  [ -n "$PORT_SHADOWSOCKS" ] && cat >> $WORK_DIR/list << EOF

$(info "- {name: \"${NODE_NAME} ss\", type: ss, server: ${SERVER_IP}, port: ${PORT_SHADOWSOCKS}, cipher: aes-128-gcm, password: \"${UUID}\", smux: { enabled: true, protocol: 'h2mux', padding: true, max-connections: '8', min-streams: '16', statistic: true, only-tcp: false } }")
EOF
  [ -n "$PORT_TROJAN" ] && cat >> $WORK_DIR/list << EOF

$(info "- {name: \"${NODE_NAME} trojan\", type: trojan, server: ${SERVER_IP}, port: ${PORT_TROJAN}, password: ${UUID}, client-fingerprint: random, skip-cert-verify: true, smux: { enabled: true, protocol: 'h2mux', padding: true, max-connections: '8', min-streams: '16', statistic: true, only-tcp: false } }")
EOF
  [ -n "$PORT_VMESS_WS" ] && TYPE_HOST_DOMAIN=$VMESS_HOST_DOMAIN && TYPE_PORT_WS=$PORT_VMESS_WS && cat >> $WORK_DIR/list << EOF

$(info "- {name: \"${NODE_NAME} vmess ws\", type: vmess, server: ${CDN}, port: 80, uuid: ${UUID}, udp: true, tls: false, alterId: 0, cipher: none, skip-cert-verify: true, network: ws, ws-opts: { path: \"/${UUID}-vmess\", headers: { Host: ${VMESS_HOST_DOMAIN}, max-early-data: 2048, early-data-header-name: Sec-WebSocket-Protocol} }, smux: { enabled: true, protocol: 'h2mux', padding: true, max-connections: '8', min-streams: '16', statistic: true, only-tcp: false } }

$(text 52)")
EOF
  [ -n "$PORT_VLESS_WS" ] && TYPE_HOST_DOMAIN=$VLESS_HOST_DOMAIN && TYPE_PORT_WS=$PORT_VLESS_WS && cat >> $WORK_DIR/list << EOF

$(info "- {name: \"${NODE_NAME} vless ws\", type: vless, server: ${CDN}, port: 443, uuid: ${UUID}, udp: true, tls: true, servername: ${VLESS_HOST_DOMAIN}, network: ws, skip-cert-verify: true, ws-opts: { path: \"/${UUID}-vless?ed=2048\", headers: { Host: ${VLESS_HOST_DOMAIN} } }, smux: { enabled: true, protocol: 'h2mux', padding: true, max-connections: '8', min-streams: '16', statistic: true, only-tcp: false } }

$(text 52)")
EOF
  [ -n "$PORT_GRPC_REALITY" ] && cat >> $WORK_DIR/list << EOF

$(info "- {name: \"${NODE_NAME} vless-reality-grpc\", type: vless, server: ${SERVER_IP}, port: ${PORT_GRPC_REALITY}, uuid: ${UUID}, network: grpc, tls: true, udp: true, flow:, client-fingerprint: chrome, servername: ${TLS_SERVER}, grpc-opts: {  grpc-service-name: \"grpc\" }, reality-opts: { public-key: ${REALITY_PUBLIC}, short-id: \"\" }, smux: { enabled: true, protocol: 'h2mux', padding: true, max-connections: '8', min-streams: '16', statistic: true, only-tcp: false } }")
EOF

  cat >> $WORK_DIR/list << EOF

*******************************************
┌────────────────┐
│                │
│    $(warning "NekoBox")     │
│                │
└────────────────┘
EOF
  [ -n "$PORT_XTLS_REALITY" ] && cat >> $WORK_DIR/list << EOF
----------------------------
$(hint "vless://${UUID}@${SERVER_IP_1}:${PORT_XTLS_REALITY}?security=reality&sni=${TLS_SERVER}&fp=chrome&pbk=${REALITY_PUBLIC}&type=tcp&encryption=none#${NODE_NAME}%20xtls-reality")
EOF
  [ -n "$PORT_HYSTERIA2" ] && cat >> $WORK_DIR/list << EOF
----------------------------
$(hint "hy2://${UUID}@${SERVER_IP_1}:${PORT_HYSTERIA2}?obfs=salamander&obfs-password=${UUID}&insecure=1#${NODE_NAME}%20hysteria2")
EOF
  [ -n "$PORT_TUIC" ] && cat >> $WORK_DIR/list << EOF
----------------------------
$(hint "tuic://${UUID}:${UUID}@${SERVER_IP_1}:${PORT_TUIC}?congestion_control=bbr&alpn=h3&udp_relay_mode=native&allow_insecure=1&disable_sni=1#${NODE_NAME}%20tuic")
EOF
  [ -n "$PORT_SHADOWTLS" ] && cat >> $WORK_DIR/list << EOF
----------------------------
$(hint "nekoray://custom#$(base64 -w0 <<< "{\"_v\":0,\"addr\":\"127.0.0.1\",\"cmd\":[\"\"],\"core\":\"internal\",\"cs\":\"{\n    \\\"password\\\": \\\"${UUID}\\\",\n    \\\"server\\\": \\\"${SERVER_IP_1}\\\",\n    \\\"server_port\\\": ${PORT_SHADOWTLS},\n    \\\"tag\\\": \\\"shadowtls-out\\\",\n    \\\"tls\\\": {\n        \\\"enabled\\\": true,\n        \\\"server_name\\\": \\\"addons.mozilla.org\\\"\n    },\n    \\\"type\\\": \\\"shadowtls\\\",\n    \\\"version\\\": 3\n}\n\",\"mapping_port\":0,\"name\":\"1-tls-not-use\",\"port\":1080,\"socks_port\":0}")

nekoray://shadowsocks#$(base64 -w0 <<< "{\"_v\":0,\"method\":\"2022-blake3-aes-128-gcm\",\"name\":\"2-ss-not-use\",\"pass\":\"${SHADOWTLS_PASSWORD}\",\"port\":0,\"stream\":{\"ed_len\":0,\"insecure\":false,\"mux_s\":0,\"net\":\"tcp\"},\"uot\":0}")

 $(text 48)")
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
$(hint "vmess://$(base64 -w0 <<< "{\"add\":\"${CDN}\",\"aid\":\"0\",\"host\":\"${VMESS_HOST_DOMAIN}\",\"id\":\"${UUID}\",\"net\":\"ws\",\"path\":\"/${UUID}-vmess\",\"port\":\"80\",\"ps\":\"${NODE_NAME} vmess ws\",\"scy\":\"none\",\"sni\":\"\",\"tls\":\"\",\"type\":\"\",\"v\":\"2\"}" | sed "s/Cg==$//")

$(text 52)")
EOF
  [ -n "$PORT_VLESS_WS" ] && TYPE_HOST_DOMAIN=$VLESS_HOST_DOMAIN && TYPE_PORT_WS=$PORT_VLESS_WS && cat >> $WORK_DIR/list << EOF
----------------------------
$(hint "vless://${UUID}@${CDN}:443?security=tls&sni=${VLESS_HOST_DOMAIN}&type=ws&path=/${UUID}-vless?ed%3D2048&host=${VLESS_HOST_DOMAIN}&encryption=none#${NODE_NAME}%20vless%20ws

$(text 52)")
EOF
  [ -n "$PORT_H2_REALITY" ] && cat >> $WORK_DIR/list << EOF
----------------------------
$(hint "vless://${UUID}@${SERVER_IP_1}:${PORT_H2_REALITY}?security=reality&sni=${TLS_SERVER}&alpn=h2&fp=chrome&pbk=${REALITY_PUBLIC}&type=http&encryption=none#${NODE_NAME}%20h2-reality-vision")
EOF
  [ -n "$PORT_GRPC_REALITY" ] && cat >> $WORK_DIR/list << EOF
----------------------------
$(hint "vless://${UUID}@${SERVER_IP_1}:${PORT_GRPC_REALITY}?security=reality&sni=${TLS_SERVER}&fp=chrome&pbk=${REALITY_PUBLIC}&type=grpc&serviceName=grpc&encryption=none#${NODE_NAME}%20grpc-reality-vision")
EOF

  cat >> $WORK_DIR/list << EOF

*******************************************
┌────────────────┐
│                │
│    $(warning "Sing-box")    │
│                │
└────────────────┘
----------------------------
$(info "{
  \"outbounds\":[")
EOF
  [ -n "$PORT_XTLS_REALITY" ] && cat >> $WORK_DIR/list << EOF
$(info "      {
        \"type\": \"vless\",
        \"tag\": \"${NODE_NAME} xtls-reality\",
        \"server\":\"${SERVER_IP}\",
        \"server_port\":${PORT_XTLS_REALITY},
        \"uuid\":\"${UUID}\",
        \"flow\":\"\",
        \"packet_encoding\":\"xudp\",
        \"tls\":{
            \"enabled\":true,
            \"server_name\":\"${TLS_SERVER}\",
            \"utls\":{
                \"enabled\":true,
                \"fingerprint\":\"chrome\"
            },
            \"reality\":{
                \"enabled\":true,
                \"public_key\":\"${REALITY_PUBLIC}\",
                \"short_id\":\"\"
            }
        },
        \"multiplex\": {
          \"enabled\": true,
          \"protocol\": \"h2mux\",
          \"max_connections\": 8,
          \"min_streams\": 16,
          \"padding\": true
        }
      },")
EOF
  [ -n "$PORT_HYSTERIA2" ] && cat >> $WORK_DIR/list << EOF
$(info "      {
        \"type\": \"hysteria2\",
        \"tag\": \"${NODE_NAME} hysteria2\",
        \"server\": \"${SERVER_IP}\",
        \"server_port\": ${PORT_HYSTERIA2},
        \"up_mbps\": 200,
        \"down_mbps\": 1000,
        \"obfs\": {
          \"type\": \"salamander\",
          \"password\": \"${UUID}\"
        },
        \"password\": \"${UUID}\",
        \"tls\": {
            \"enabled\": true,
            \"insecure\": true,
            \"server_name\": \"\",
            \"alpn\": [ \"h3\" ]
        }
      },")
EOF
  [ -n "$PORT_TUIC" ] && cat >> $WORK_DIR/list << EOF
$(info "      {
        \"type\": \"tuic\",
        \"tag\": \"${NODE_NAME} tuic\",
        \"server\": \"${SERVER_IP}\",
        \"server_port\": ${PORT_TUIC},
        \"uuid\": \"${UUID}\",
        \"password\": \"${UUID}\",
        \"congestion_control\": \"bbr\",
        \"udp_relay_mode\": \"native\",
        \"zero_rtt_handshake\": false,
        \"heartbeat\": \"10s\",
        \"tls\": {
            \"enabled\": true,
            \"insecure\": true,
            \"server_name\": \"\",
            \"alpn\": [ \"h3\" ]
        }
      },")
EOF
  [ -n "$PORT_SHADOWTLS" ] && cat >> $WORK_DIR/list << EOF
$(info "      {
        \"type\": \"shadowsocks\",
        \"tag\": \"${NODE_NAME} ShadowTLS v3\",
        \"method\": \"2022-blake3-aes-128-gcm\",
        \"password\": \"${SHADOWTLS_PASSWORD}\",
        \"detour\": \"shadowtls-out\",
        \"udp_over_tcp\": false,
        \"multiplex\": {
          \"enabled\": true,
          \"protocol\": \"h2mux\",
          \"max_connections\": 8,
          \"min_streams\": 16,
          \"padding\": true
        }
      },
      {
        \"type\": \"shadowtls\",
        \"tag\": \"shadowtls-out\",
        \"server\": \"${SERVER_IP}\",
        \"server_port\": ${PORT_SHADOWTLS},
        \"version\": 3,
        \"password\": \"${UUID}\",
        \"tls\": {
          \"enabled\": true,
          \"server_name\": \"${TLS_SERVER}\",
          \"utls\": {
            \"enabled\": true,
            \"fingerprint\": \"chrome\"
          }
        }
      },")
EOF
  [ -n "$PORT_SHADOWSOCKS" ] && cat >> $WORK_DIR/list << EOF
$(info "      {
        \"type\": \"shadowsocks\",
        \"tag\": \"${NODE_NAME} ss\",
        \"server\": \"${SERVER_IP}\",
        \"server_port\": ${PORT_SHADOWSOCKS},
        \"method\": \"aes-128-gcm\",
        \"password\": \"${UUID}\",
        \"multiplex\": {
          \"enabled\": true,
          \"protocol\": \"h2mux\",
          \"max_connections\": 8,
          \"min_streams\": 16,
          \"padding\": true
        }
      },")
EOF
  [ -n "$PORT_TROJAN" ] && cat >> $WORK_DIR/list << EOF
$(info "      {
        \"type\": \"trojan\",
        \"tag\": \"${NODE_NAME} trojan\",
        \"server\": \"${SERVER_IP}\",
        \"server_port\": ${PORT_TROJAN},
        \"password\": \"${UUID}\",
        \"tls\": {
          \"enabled\":true,
          \"insecure\": true,
          \"server_name\":\"\",
          \"utls\": {
            \"enabled\":true,
            \"fingerprint\":\"chrome\"
          }
        },
        \"multiplex\": {
          \"enabled\":true,
          \"protocol\":\"h2mux\",
          \"max_connections\": 8,
          \"min_streams\": 16,
          \"padding\": true
        }
      },")
EOF
  [ -n "$PORT_VMESS_WS" ] && TYPE_HOST_DOMAIN=$VMESS_HOST_DOMAIN && TYPE_PORT_WS=$PORT_VMESS_WS && cat >> $WORK_DIR/list << EOF
$(info "      {
        \"type\": \"vmess\",
        \"tag\": \"${NODE_NAME} vmess ws\",
        \"server\":\"${CDN}\",
        \"server_port\":80,
        \"uuid\":\"${UUID}\",
        \"transport\": {
          \"type\":\"ws\",
          \"path\":\"/${UUID}-vmess\",
          \"headers\": {
            \"Host\": \"${VMESS_HOST_DOMAIN}\"
          },
          \"max_early_data\":2048,
          \"early_data_header_name\":\"Sec-WebSocket-Protocol\"
        },
        \"multiplex\": {
          \"enabled\":true,
          \"protocol\":\"h2mux\",
          \"max_streams\":16,
          \"padding\": true
        }
      },")
EOF
  [ -n "$PORT_VLESS_WS" ] && TYPE_HOST_DOMAIN=$VLESS_HOST_DOMAIN && TYPE_PORT_WS=$PORT_VLESS_WS && cat >> $WORK_DIR/list << EOF
$(info "      {
        \"type\": \"vless\",
        \"tag\": \"${NODE_NAME} vless ws\",
        \"server\":\"${CDN}\",
        \"server_port\":443,
        \"uuid\":\"${UUID}\",
        \"tls\": {
          \"enabled\":true,
          \"server_name\":\"${VLESS_HOST_DOMAIN}\",
          \"utls\": {
            \"enabled\":true,
            \"fingerprint\":\"chrome\"
          }
        },
        \"transport\": {
          \"type\":\"ws\",
          \"path\":\"/${UUID}-vless\",
          \"headers\": {
            \"Host\": \"${VLESS_HOST_DOMAIN}\"
          },
          \"max_early_data\":2048,
          \"early_data_header_name\":\"Sec-WebSocket-Protocol\"
        },
        \"multiplex\": {
          \"enabled\":true,
          \"protocol\":\"h2mux\",
          \"max_streams\":16,
          \"padding\": true
        }
      },")
EOF
  [ -n "$PORT_H2_REALITY" ] && cat >> $WORK_DIR/list << EOF
$(info "      {
        \"type\": \"vless\",
        \"tag\": \"${NODE_NAME} h2-reality-vision\",
         \"server\": \"${SERVER_IP}\",
        \"server_port\": ${PORT_H2_REALITY},
        \"uuid\":\"${UUID}\",
        \"tls\": {
          \"enabled\":true,
          \"server_name\":\"${TLS_SERVER}\",
          \"utls\": {
            \"enabled\":true,
            \"fingerprint\":\"chrome\"
          },
          \"reality\":{
              \"enabled\":true,
              \"public_key\":\"${REALITY_PUBLIC}\",
              \"short_id\":\"\"
          }
        },
        \"packet_encoding\": \"xudp\",
        \"transport\": {
            \"type\": \"http\"
        },
        \"multiplex\": {
          \"enabled\":true,
          \"protocol\":\"h2mux\",
          \"max_streams\":16,
          \"padding\": true
        }
      },")
EOF
  [ -n "$PORT_GRPC_REALITY" ] && cat >> $WORK_DIR/list << EOF
$(info "      {
        \"type\": \"vless\",
        \"tag\": \"${NODE_NAME} grpc-reality-vision\",
        \"server\": \"${SERVER_IP}\",
        \"server_port\": ${PORT_GRPC_REALITY},
        \"uuid\":\"${UUID}\",
        \"tls\": {
          \"enabled\":true,
          \"server_name\":\"${TLS_SERVER}\",
          \"utls\": {
            \"enabled\":true,
            \"fingerprint\":\"chrome\"
          },
          \"reality\":{
              \"enabled\":true,
              \"public_key\":\"${REALITY_PUBLIC}\",
              \"short_id\":\"\"
          }
        },
        \"packet_encoding\": \"xudp\",
        \"transport\": {
            \"type\": \"grpc\",
            \"service_name\": \"grpc\"
        }
      },")
EOF

sed -i '$s/},/}/' $WORK_DIR/list

  cat >> $WORK_DIR/list << EOF
$(info "  ]
}

 $(text 72)")
EOF

  [ -n "$PORT_VMESS_WS" ] && TYPE_HOST_DOMAIN=$VMESS_HOST_DOMAIN && TYPE_PORT_WS=$PORT_VMESS_WS && hint "\n $(text 52)" >> $WORK_DIR/list

  [ -n "$PORT_VLESS_WS" ] && TYPE_HOST_DOMAIN=$VLESS_HOST_DOMAIN && TYPE_PORT_WS=$PORT_VLESS_WS && hint "\n $(text 52)" >> $WORK_DIR/list


  # 显示节点信息
  cat $WORK_DIR/list

  # 显示脚本使用情况数据
  info "\n $(text 55) \n"
}

# 创建快捷方式
create_shortcut() {
  cat > $WORK_DIR/sb.sh << EOF
#!/usr/bin/env bash

bash <(wget --no-check-certificate -qO- https://raw.githubusercontent.com/fscarmen/sing-box/main/sing-box.sh) \$1
EOF
  chmod +x $WORK_DIR/sb.sh
  ln -sf $WORK_DIR/sb.sh /usr/bin/sb
  [ -s /usr/bin/sb ] && info "\n $(text 71) "
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

# 增加或删除协议
change_protocols() {
  check_install
  [ "$STATUS" = "$(text 26)" ] && error "\n Sing-box $(text 26) "

  # 查找已安装的协议，并遍历其在所有协议列表中的名称，获取协议名后存放在 EXISTED_PROTOCOLS
  EXISTED_CHECK=($(sed -n "/tag/s/.*\"tag\":\"\(.*\)-in.*/\1/gp" $WORK_DIR/conf/*_inbounds.json | sed "s/xtls-reality/XTLS@+@reality/; s/shadowtls/shadowTLS/; s/vmess-ws/vmess@+@ws/; s/vless-ws/vless@+@ws@+@tls/; s/h2-reality/H2@+@reality/; s/grpc-reality/gRPC@+@reality/"))
  for f in "${EXISTED_CHECK[@]}"; do
    [[ "$(tr 'A-Z' 'a-z' <<< "${PROTOCOL_LIST[@]// /@}")" =~ "$(tr 'A-Z' 'a-z' <<< "$f")" ]] && EXISTED_PROTOCOLS+=("$f")
  done

  # 查找未安装的协议，并遍历所有协议列表的数组，获取协议名后存放在 NOT_EXISTED_PROTOCOLS
  for g in "${PROTOCOL_LIST[@]// /@}"; do
    [[ ! "${EXISTED_CHECK[@]}" =~ "$g" ]] && NOT_EXISTED_PROTOCOLS+=("$g")
  done

  # 列出已安装协议
  hint "\n $(text 63) (${#EXISTED_PROTOCOLS[@]})"
  for h in "${!EXISTED_PROTOCOLS[@]}"; do
    hint " $(asc $[h+97]). ${EXISTED_PROTOCOLS[h]//@/ } "
  done

  # 从已安装的协议中选择需要删除的协议名，并存放在 REMOVE_PROTOCOLS，把保存的协议的协议存放在 KEEP_PROTOCOLS
  reading "\n $(text 64) " REMOVE_SELECT
  for ((j=0; j<${#REMOVE_SELECT}; j++)); do
    REMOVE_PROTOCOLS+=(${EXISTED_PROTOCOLS[$[$(asc "$(awk "NR==$[j+1] {print}" <<< "$(grep -o . <<< "$REMOVE_SELECT")")") - 97]]})
  done

  for k in "${EXISTED_PROTOCOLS[@]}"; do
    [[ ! "${REMOVE_PROTOCOLS[@]}" =~ "$k" ]] && KEEP_PROTOCOLS+=("$k")
  done

  # 如有未安装的协议，列表显示并选择安装，把增加的协议存在放在 ADD_PROTOCOLS
  if [ "${#NOT_EXISTED_PROTOCOLS[@]}" -gt 0 ]; then
    hint "\n $(text 65) (${#NOT_EXISTED_PROTOCOLS}) "
    for i in "${!NOT_EXISTED_PROTOCOLS[@]}"; do
      hint " $(asc $[i+97]). ${NOT_EXISTED_PROTOCOLS[i]//@/ } "
    done
    reading "\n $(text 66) " ADD_SELECT

    for ((l=0; l<${#ADD_SELECT}; l++)); do
      ADD_PROTOCOLS+=(${NOT_EXISTED_PROTOCOLS[$[$(asc "$(awk "NR==$[l+1] {print}" <<< "$(grep -o . <<< "$ADD_SELECT")")") - 97]]})
    done
  fi

  # 重新安装 = 保留 + 新增，如数量为 0 ，则触发卸载
  REINSTALL_PROTOCOLS=(${KEEP_PROTOCOLS[@]} ${ADD_PROTOCOLS[@]})
  [ "${#REINSTALL_PROTOCOLS[@]}" = 0 ] && error "\n $(text 73) "

  # 显示重新安装的协议列表，并确认是否正确
  hint "\n $(text 67) (${#REINSTALL_PROTOCOLS[@]}) "
  [ "${#KEEP_PROTOCOLS[@]}" -gt 0 ] && hint "\n $(text 74) (${#KEEP_PROTOCOLS[@]}) "
  for r in "${!KEEP_PROTOCOLS[@]}"; do
    hint " $[r+1]. ${KEEP_PROTOCOLS[r]//@/ } "
  done

  [ "${#ADD_PROTOCOLS[@]}" -gt 0 ] && hint "\n $(text 75) (${#ADD_PROTOCOLS[@]}) "
  for r in "${!ADD_PROTOCOLS[@]}"; do
    hint " $[r+1]. ${ADD_PROTOCOLS[r]//@/ } "
  done

  reading "\n $(text 68) " CONFIRM
  [[ "$CONFIRM" = [Nn] ]] && exit 0

  # 把确认安装的协议遍历所有协议列表的数组，找出其下标并变为英文小写的形式
  for m in "${!REINSTALL_PROTOCOLS[@]}"; do
    for n in "${!PROTOCOL_LIST[@]}"; do
      if [[ "$(awk -F '@' '{print $1}' <<< "${REINSTALL_PROTOCOLS[m]}")" = "$(awk -F ' ' '{print $1}' <<< "${PROTOCOL_LIST[n]}")" ]]; then
        INSTALL_PROTOCOLS+=($(asc $[n+98]))
      fi
    done
  done

  systemctl stop sing-box

  # 获取原有各协议的参数
  if [ -s $WORK_DIR/list ]; then
    SERVER_IP=$(sed -r "s/\x1B\[[0-9;]*[mG]//g" $WORK_DIR/list | sed -n "s/.*{name.*server:[ ]*\([^,]\+\).*/\1/pg" | sed -n '1p')
    UUID=$(sed -r "s/\x1B\[[0-9;]*[mG]//g" $WORK_DIR/list | grep -m1 '{name' | sed -En 's/.*password:[ ]+[\"]*|.*uuid:[ ]+[\"]*(.*)/\1/gp' | sed "s/\([^,\"]\+\).*/\1/g")
    NODE_NAME=$(sed -r "s/\x1B\[[0-9;]*[mG]//g" $WORK_DIR/list | grep -m1 '{name' | sed 's/- {name:[ ]\+"//; s/[ ]\+ShadowTLS[ ]\+v3.*//; s/[ ]\+xtls-reality.*//; s/[ ]\+hysteria2.*//; s/[ ]\+tuic.*//; s/[ ]\+ss.*//; s/[ ]\+trojan.*//; s/[ ]\+trojan.*//; s/[ ]\+vmess[ ]\+ws.*//; s/[ ]\+vless[ ]\+.*//')
    EXISTED_PORTS=$(awk -F ':|,' '/listen_port/{print $2}' $WORK_DIR/conf/*)
    START_PORT=$(awk 'NR == 1 { min = $0 } { if ($0 < min) min = $0; count++ } END {print min}' <<< "$EXISTED_PORTS")
    [ -s $WORK_DIR/conf/*_VMESS_WS_inbounds.json ] && WS_SERVER_IP=$(grep -A2 "{name.*vmess[ ]\+ws" $WORK_DIR/list | awk -F'[][]' 'NR==3 {print $2}') && VMESS_HOST_DOMAIN=$(grep -A2 "{name.*vmess[ ]\+ws" $WORK_DIR/list | awk -F'[][]' 'NR==3 {print $4}') && CDN=$(sed -n "s/.*{name.*vmess[ ]\+ws.*server:[ ]\+\([^,]\+\).*/\1/gp" $WORK_DIR/list)
    [ -s $WORK_DIR/conf/*_VLESS_WS_inbounds.json ] && WS_SERVER_IP=$(grep -A2 "{name.*vless[ ]\+ws" $WORK_DIR/list | awk -F'[][]' 'NR==3 {print $2}') && VLESS_HOST_DOMAIN=$(grep -A2 "{name.*vless[ ]\+ws" $WORK_DIR/list | awk -F'[][]' 'NR==3 {print $4}') && CDN=$(sed -n "s/.*{name.*vless[ ]\+ws.*server:[ ]\+\([^,]\+\).*/\1/gp" $WORK_DIR/list)
  fi

  # 删除不需要的协议配置文件
  for o in "${REMOVE_PROTOCOLS[@]}"; do
    rm -f $WORK_DIR/conf/*$(tr 'a-z' 'A-Z' <<< "$o" | awk -F '@' '{print $1}')*inbounds.json
  done

  # 寻找已存在协议中原有的端口号
  for p in "${KEEP_PROTOCOLS[@]}"; do
    KEEP_PORTS+=($(awk -F '[:,]' '/listen_port/{print $2}' $WORK_DIR/conf/*$(tr 'a-z' 'A-Z' <<< "$p" | awk -F '@' '{print $1}')*inbounds.json))
  done

  # 根据全部协议，找到空余的端口号
  for q in "${!REINSTALL_PROTOCOLS[@]}"; do
    [[ ! ${KEEP_PORTS[@]} =~ $[START_PORT + q] ]] && ADD_PORTS+=($[START_PORT + q])
  done

  # 所有协议的端口号
  REINSTALL_PORTS=(${KEEP_PORTS[@]} ${ADD_PORTS[@]})

  CHECK_PROTOCOLS=b
  # 获取原始 Reality 配置信息
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    if [[ "${KEEP_PROTOCOLS[@]}" =~ "reality" ]]; then
      REALITY_PRIVATE=$(awk -F '"' '/private_key/{print $4; exit}' $WORK_DIR/conf/*_REALITY_inbounds.json)
      REALITY_PUBLIC=$(sed -n 's/.*{name.*public-key:[ ]*\([^,]\+\).*/\1/pg' $WORK_DIR/list | sed -n 1p)
    else
      REALITY_KEYPAIR=$($WORK_DIR/sing-box generate reality-keypair)
      REALITY_PRIVATE=$(awk '/PrivateKey/{print $NF}' <<< "$REALITY_KEYPAIR")
      REALITY_PUBLIC=$(awk '/PublicKey/{print $NF}' <<< "$REALITY_KEYPAIR")
    fi
    PORT_XTLS_REALITY=${REINSTALL_PORTS[$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")]}
  fi

  # 获取原始 Hysteria2 配置信息
  CHECK_PROTOCOLS=$(asc "$CHECK_PROTOCOLS" ++)
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    PORT_HYSTERIA2=${REINSTALL_PORTS[$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")]}
  fi

  # 获取原始 Tuic V5 配置信息
  CHECK_PROTOCOLS=$(asc "$CHECK_PROTOCOLS" ++)
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    PORT_TUIC=${REINSTALL_PORTS[$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")]}
  fi

  # 获取原始 shadowTLS 配置信息
  CHECK_PROTOCOLS=$(asc "$CHECK_PROTOCOLS" ++)
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    [[ "${KEEP_PROTOCOLS[@]}" =~ "shadowTLS" ]] && SHADOWTLS_PASSWORD=$(sed -r "s/\x1B\[[0-9;]*[mG]//g" $WORK_DIR/list | sed -n 's/.*{name.*password:[ ]*\"\([^\"]\+\)".*shadow-tls.*/\1/pg') || SHADOWTLS_PASSWORD=$($WORK_DIR/sing-box generate rand --base64 16)
    PORT_SHADOWTLS=${REINSTALL_PORTS[$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")]}
  fi

  # 获取原始 Shadowsocks 配置信息
  CHECK_PROTOCOLS=$(asc "$CHECK_PROTOCOLS" ++)
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    PORT_SHADOWSOCKS=${REINSTALL_PORTS[$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")]}
  fi

  # 获取原始 Trojan 配置信息
  CHECK_PROTOCOLS=$(asc "$CHECK_PROTOCOLS" ++)
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    PORT_TROJAN=${REINSTALL_PORTS[$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")]}
  fi

  # 获取原始 vmess + ws 配置信息
  CHECK_PROTOCOLS=$(asc "$CHECK_PROTOCOLS" ++)
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    WS_SERVER_IP=$SERVER_IP
    local DOMAIN_ERROR_TIME=5
    until [ -n "$VMESS_HOST_DOMAIN" ]; do
      (( DOMAIN_ERROR_TIME-- )) || true
      [ "$DOMAIN_ERROR_TIME" != 0 ] && TYPE=VMESS && reading "\n $(text 50) " VMESS_HOST_DOMAIN || error "\n $(text 3) \n"
    done
    PORT_VMESS_WS=${REINSTALL_PORTS[$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")]}
  fi

  # 获取原始 vless + ws + tls 配置信息
  CHECK_PROTOCOLS=$(asc "$CHECK_PROTOCOLS" ++)
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    WS_SERVER_IP=$SERVER_IP
    local DOMAIN_ERROR_TIME=5
    until [ -n "$VLESS_HOST_DOMAIN" ]; do
      (( DOMAIN_ERROR_TIME-- )) || true
      [ "$DOMAIN_ERROR_TIME" != 0 ] && TYPE=VLESS && reading "\n $(text 50) " VLESS_HOST_DOMAIN || error "\n $(text 3) \n"
    done
    PORT_VLESS_WS=${REINSTALL_PORTS[$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")]}
  fi

  # 选择可以输入 cdn
  input_cdn

  # 生成各协议的 json 文件
  sing-box_json change

  systemctl start sing-box

  # 再次检测状态，运行 Sing-box
  check_install

  check_sing-box_stats

  export_list
}

# 卸载 Sing-box 全家桶
uninstall() {
  if [ -d $WORK_DIR ]; then
    [ "$SYSTEM" = 'Alpine' ] && systemctl stop sing-box 2>/dev/null || cmd_systemctl disable sing-box 2>/dev/null
    rm -rf $WORK_DIR $TEMP_DIR /etc/systemd/system/sing-box.service /usr/bin/sb
    info "\n $(text 16) \n"
  else
    error "\n $(text 15) \n"
  fi

  # 如果 Alpine 系统，删除开机自启动
  [ "$SYSTEM" = 'Alpine' ] && ( rm -f /etc/local.d/sing-box.start; rc-update add local >/dev/null 2>&1 )
}

# Sing-box 的最新版本
version() {
  local ONLINE=$(wget --no-check-certificate -qO- "https://api.github.com/repos/SagerNet/sing-box/releases" | awk -F '["v]' '/tag_name.*beta/{print $5; exit}')
  local LOCAL=$($WORK_DIR/sing-box version | awk '/version/{print $NF}')
  info "\n $(text 40) "
  [[ -n "$ONLINE" && "$ONLINE" != "$LOCAL" ]] && reading "\n $(text 9) " UPDATE || info " $(text 41) "

  if [[ "$UPDATE" = [Yy] ]]; then
    check_system_info
    wget --no-check-certificate -c ${GH_PROXY}https://github.com/SagerNet/sing-box/releases/download/v$ONLINE/sing-box-$ONLINE-linux-$SING_BOX_ARCH.tar.gz -qO- | tar xz -C $TEMP_DIR sing-box-$ONLINE-linux-$SING_BOX_ARCH/sing-box

    if [ -s $TEMP_DIR/sing-box-$ONLINE-linux-$SING_BOX_ARCH/sing-box ]; then
      systemctl stop sing-box
      chmod +x $TEMP_DIR/sing-box-$ONLINE-linux-$SING_BOX_ARCH/sing-box && mv $TEMP_DIR/sing-box-$ONLINE-linux-$SING_BOX_ARCH/sing-box $WORK_DIR/sing-box
      systemctl start sing-box && sleep 2 && [ "$(systemctl is-active sing-box)" = 'active' ] && info " Sing-box $(text 28) $(text 37)" || error "Sing-box $(text 28) $(text 38) "
    else
      local error "\n $(text 42) "
    fi
  fi
}

# 判断当前 Sing-box 的运行状态，并对应的给菜单和动作赋值
menu_setting() {
  OPTION[0]="0 .  $(text 35)"
  ACTION[0]() { exit; }

  if [[ "$STATUS" =~ $(text 27)|$(text 28) ]]; then
    # 查进程号，sing-box 运行时长 和 内存占用
    if [ "$STATUS" = "$(text 28)" ]; then
      if [ "$SYSTEM" = 'Alpine' ]; then
        PID=$(pidof sing-box | sed -n 1p)
      else
        SYSTEMCTL_STATUS=$(systemctl status sing-box)
        PID=$(awk '/PID/{print $3}' <<< "$SYSTEMCTL_STATUS")
        RUNTIME=$(awk '/Active:/{for (i=5;i<=NF;i++)printf("%s ", $i);print ""}' <<< "$SYSTEMCTL_STATUS")
      fi
      MEMORY_USAGE="$(awk '/VmRSS/{printf "%.1f\n", $2/1024}' /proc/$PID/status)"
    fi
    NOW_PORTS=$(awk -F ':|,' '/listen_port/{print $2}' $WORK_DIR/conf/*)
    NOW_START_PORT=$(awk 'NR == 1 { min = $0 } { if ($0 < min) min = $0; count++ } END {print min}' <<< "$NOW_PORTS")
    NOW_CONSECUTIVE_PORTS=$(awk 'END { print NR }' <<< "$NOW_PORTS")
    [ -s $WORK_DIR/sing-box ] && SING_BOX_VERSION="version: $($WORK_DIR/sing-box version | awk '/version/{print $NF}')"
    [ -s $WORK_DIR/conf/02_route.json ] && { grep -q 'direct' $WORK_DIR/conf/02_route.json && RETURN_STATUS=$(text 27) || RETURN_STATUS=$(text 28); }
    OPTION[1]="1 .  $(text 29)"
    [ "$STATUS" = "$(text 28)" ] && OPTION[2]="2 .  $(text 27) Sing-box (sb -o)" || OPTION[2]="2 .  $(text 28) Sing-box (sb -o)"
    OPTION[3]="3 .  $(text 30)"
    OPTION[4]="4 .  $(text 31)"
    OPTION[5]="5 .  $(text 32)"
    OPTION[6]="6 .  $(text 62)"
    OPTION[7]="7 .  $(text 33)"
    OPTION[8]="8 .  $(text 59)"
    OPTION[9]="9 .  $(text 69)"
    OPTION[10]="10.  $(text 76)"

    ACTION[1]() { export_list; exit 0; }
    [ "$STATUS" = "$(text 28)" ] && ACTION[2]() { cmd_systemctl disable sing-box; [ "$(systemctl is-active sing-box)" = 'inactive' ] && info " Sing-box $(text 27) $(text 37)" || error " Sing-box $(text 27) $(text 38) "; } || ACTION[2]() { cmd_systemctl enable sing-box && [ "$(systemctl is-active sing-box)" = 'active' ] && info " Sing-box $(text 28) $(text 37)" || error " Sing-box $(text 28) $(text 38) "; }
    ACTION[3]() { change_start_port; exit; }
    ACTION[4]() { version; exit; }
    ACTION[5]() { bash <(wget --no-check-certificate -qO- "https://raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master/tcp.sh"); exit; }
    ACTION[6]() { change_protocols; exit; }
    ACTION[7]() { uninstall; exit; }
    ACTION[8]() { bash <(wget --no-check-certificate -qO- https://raw.githubusercontent.com/fscarmen/argox/main/argox.sh) -$L; exit; }
    ACTION[9]() { bash <(wget --no-check-certificate -qO- https://raw.githubusercontent.com/fscarmen/sba/main/sba.sh) -$L; exit; }
    ACTION[10]() { bash <(wget --no-check-certificate -qO- https://tcp.hy2.sh/); exit; }
  else
    OPTION[1]="1.  $(text 34)"
    OPTION[2]="2.  $(text 32)"
    OPTION[3]="3.  $(text 59)"
    OPTION[4]="4.  $(text 69)"
    OPTION[5]="5.  $(text 76)"

    ACTION[1]() { install_sing-box; export_list; create_shortcut; exit; }
    ACTION[2]() { bash <(wget --no-check-certificate -qO- "https://raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master/tcp.sh"); exit; }
    ACTION[3]() { bash <(wget --no-check-certificate -qO- https://raw.githubusercontent.com/fscarmen/argox/main/argox.sh) -$L; exit; }
    ACTION[4]() { bash <(wget --no-check-certificate -qO- https://raw.githubusercontent.com/fscarmen/sba/main/sba.sh) -$L; exit; }
    ACTION[5]() { bash <(wget --no-check-certificate -qO- https://tcp.hy2.sh/); exit; }
  fi
}

menu() {
  clear
  hint " $(text 2) "
  echo -e "======================================================================================================================\n"
  info " $(text 17): $VERSION\n $(text 18): $(text 1)\n $(text 19):\n\t $(text 20): $SYS\n\t $(text 21): $(uname -r)\n\t $(text 22): $SING_BOX_ARCH\n\t $(text 23): $VIRT "
  info "\t IPv4: $WAN4 $WARPSTATUS4 $COUNTRY4  $ASNORG4 "
  info "\t IPv6: $WAN6 $WARPSTATUS6 $COUNTRY6  $ASNORG6 "
  info "\t Sing-box: $STATUS\t $SING_BOX_VERSION "
  [ -n "$PID" ] && info "\t $(text 56): $PID "
  [ -n "$RUNTIME" ] && info "\t $(text 57): $RUNTIME "
  [ -n "$MEMORY_USAGE" ] && info "\t $(text 58): $MEMORY_USAGE MB"
  [ -n "$NOW_START_PORT" ] && info "\t $(text 45) "
  echo -e "\n======================================================================================================================\n"
  for ((b=1;b<${#OPTION[*]};b++)); do hint " ${OPTION[b]} "; done
  hint " ${OPTION[0]} "
  reading "\n $(text 24) " CHOOSE

  # 输入必须是数字且少于等于最大可选项
  if grep -qE "^[0-9]{1,2}$" <<< "$CHOOSE" && [ "$CHOOSE" -lt "${#OPTION[*]}" ]; then
    ACTION[$CHOOSE]
  else
    warning " $(text 36) [0-$((${#OPTION[*]}-1))] " && sleep 1 && menu
  fi
}

statistics_of_run-times

# 传参
[[ "$*" =~ -[Ee] ]] && L=E
[[ "$*" =~ -[Cc] ]] && L=C

while getopts ":P:p:OoUuVvNnBbRr" OPTNAME; do
  case "$OPTNAME" in
    'P'|'p' ) START_PORT=$OPTARG; select_language; check_install; [ "$STATUS" = "$(text 26)" ] && error "\n Sing-box $(text 26) "; change_start_port; exit 0 ;;
    'O'|'o' ) select_language; check_system_info; check_install; [ "$STATUS" = "$(text 26)" ] && error "\n Sing-box $(text 26) "; [ "$STATUS" = "$(text 28)" ] && ( cmd_systemctl disable sing-box; [ "$(systemctl is-active sing-box)" = 'inactive' ] && info "\n Sing-box $(text 27) $(text 37)" ) || ( cmd_systemctl enable sing-box && [ "$(systemctl is-active sing-box)" = 'active' ] && info "\n Sing-box $(text 28) $(text 37)" ); exit 0;;
    'U'|'u' ) select_language; check_system_info; uninstall; exit 0 ;;
    'N'|'n' ) select_language; [ ! -s $WORK_DIR/list ] && error " Sing-box $(text 26) "; export_list; exit 0 ;;
    'V'|'v' ) select_language; check_arch; version; exit 0 ;;
    'B'|'b' ) select_language; bash <(wget --no-check-certificate -qO- "https://raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master/tcp.sh"); exit ;;
    'R'|'r' ) select_language; check_system_info; change_protocols; exit 0 ;;
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
