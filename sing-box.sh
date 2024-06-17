#!/usr/bin/env bash

# 当前脚本版本号
VERSION='v1.2.4 (2024.05.09)'

# 各变量默认值
GH_PROXY='https://ghproxy.lvedong.eu.org/'
TEMP_DIR='/tmp/sing-box'
WORK_DIR='/etc/sing-box'
START_PORT_DEFAULT='8881'
MIN_PORT=100
MAX_PORT=65520
MIN_HOPPING_PORT=10000
MAX_HOPPING_PORT=65535
TLS_SERVER_DEFAULT=addons.mozilla.org
PROTOCOL_LIST=("XTLS + reality" "hysteria2" "tuic" "ShadowTLS" "shadowsocks" "trojan" "vmess + ws" "vless + ws + tls" "H2 + reality" "gRPC + reality")
NODE_TAG=("xtls-reality" "hysteria2" "tuic" "ShadowTLS" "shadowsocks" "trojan" "vmess-ws" "vless-ws-tls" "h2-reality" "grpc-reality")
CONSECUTIVE_PORTS=${#PROTOCOL_LIST[@]}
CDN_DOMAIN=("cn.azhz.eu.org" "acjp2.cloudflarest.link" "xn--b6gac.eu.org" "dash.cloudflare.com" "skk.moe" "visa.com")
SUBSCRIBE_TEMPLATE="https://raw.githubusercontent.com/fscarmen/client_template/main"

export DEBIAN_FRONTEND=noninteractive

trap "rm -rf $TEMP_DIR >/dev/null 2>&1 ; echo -e '\n' ;exit" INT QUIT TERM EXIT

mkdir -p $TEMP_DIR

E[0]="Language:\n 1. English (default) \n 2. 简体中文"
C[0]="${E[0]}"
E[1]="Add hysteria2 port hopping. Supported Clients: ShadowRocket / NekoBox / Clash"
C[1]="添加 hysteria2 的跳跃端口，支持客户端: ShadowRocket / NekoBox / Clash"
E[2]="Downloading Sing-box. Please wait a seconds ..."
C[2]="下载 Sing-box 中，请稍等 ..."
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
E[10]="\(4/6\) Please enter VPS IP \(Default is: \${SERVER_IP_DEFAULT}\):"
C[10]="\(4/6\) 请输入 VPS IP \(默认为: \${SERVER_IP_DEFAULT}\):"
E[11]="\(2/6\) Please enter the starting port number. Must be \${MIN_PORT} - \${MAX_PORT}, consecutive \${NUM} free ports are required \(Default is: \${START_PORT_DEFAULT}\):"
C[11]="\(2/6\) 请输入开始的端口号，必须是 \${MIN_PORT} - \${MAX_PORT}，需要连续\${NUM}个空闲的端口 \(默认为: \${START_PORT_DEFAULT}\):"
E[12]="\(5/6\) Please enter UUID \(Default is \${UUID_DEFAULT}\):"
C[12]="\(5/6\) 请输入 UUID \(默认为 \${UUID_DEFAULT}\):"
E[13]="\(6/6\) Please enter the node name. \(Default is \${NODE_NAME_DEFAULT}\):"
C[13]="\(6/6\) 请输入节点名称 \(默认为: \${NODE_NAME_DEFAULT}\):"
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
E[34]="Install Sing-box"
C[34]="安装 Sing-box"
E[35]="Exit"
C[35]="退出"
E[36]="Please enter the correct number"
C[36]="请输入正确数字"
E[37]="successful"
C[37]="成功"
E[38]="failed"
C[38]="失败"
E[39]="Sing-box is not installed and cannot change the Argo tunnel."
C[39]="Sing-box 未安装，不能更换 Argo 隧道"
E[40]="Sing-box local verion: \$LOCAL\\\t The newest verion: \$ONLINE"
C[40]="Sing-box 本地版本: \$LOCAL\\\t 最新版本: \$ONLINE"
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
E[49]="(1/6) Select more protocols to install (e.g. hgbd). The order of the port numbers of the protocols is related to the ordering of the multiple choices:\n a. all (default)"
C[49]="(1/6) 多选需要安装协议(比如 hgbd)，协议的端口号次序与多选的排序有关:\n a. all (默认)"
E[50]="Please enter the \$TYPE domain name:"
C[50]="请输入 \$TYPE 域名:"
E[51]="Please choose or custom a cdn, http support is required:"
C[51]="请选择或输入 cdn，要求支持 http:"
E[52]="Please set the ip \[\${WS_SERVER_IP_SHOW}] to domain \[\${TYPE_HOST_DOMAIN}], and set the origin rule to \[\${TYPE_PORT_WS}] in Cloudflare."
C[52]="请在 Cloudflare 绑定 \[\${WS_SERVER_IP_SHOW}] 的域名为 \[\${TYPE_HOST_DOMAIN}], 并设置 origin rule 为 \[\${TYPE_PORT_WS}]"
E[53]="Please select or enter the preferred domain, the default is \${CDN_DOMAIN[0]}:"
C[53]="请选择或者填入优选域名，默认为 \${CDN_DOMAIN[0]}:"
E[54]="The contents of the ShadowTLS configuration file need to be updated for the sing_box kernel."
C[54]="ShadowTLS 配置文件内容，需要更新 sing_box 内核"
E[55]="The script runs today: \$TODAY. Total: \$TOTAL"
C[55]="脚本当天运行次数: \$TODAY，累计运行次数: \$TOTAL"
E[56]="Process ID"
C[56]="进程ID"
E[57]="Selecting the ws return method:\n 1. Argo (default)\n 2. Origin rules"
C[57]="选择 ws 的回源方式:\n 1. Argo (默认)\n 2. Origin rules"
E[58]="Memory Usage"
C[58]="内存占用"
E[59]="Install ArgoX scripts (argo + xray) [https://github.com/fscarmen/argox]"
C[59]="安装 ArgoX 脚本 (argo + xray) [https://github.com/fscarmen/argox]"
E[60]="The order of the selected protocols and ports is as follows:"
C[60]="选择的协议及端口次序如下:"
E[61]="There are no replaceable Argo tunnels."
C[61]="没有可更换的Argo 隧道"
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
E[72]="Path to each client configuration file: $WORK_DIR/subscribe/\n The full template can be found at:\n https://t.me/ztvps/100\n https://github.com/chika0801/sing-box-examples/tree/main/Tun"
C[72]="各客户端配置文件路径: $WORK_DIR/subscribe/\n 完整模板可参照:\n https://t.me/ztvps/100\n https://github.com/chika0801/sing-box-examples/tree/main/Tun"
E[73]="There is no protocol left, if you are sure please re-run [ sb -u ] to uninstall all."
C[73]="没有协议剩下，如确定请重新执行 [ sb -u ] 卸载所有"
E[74]="Keep protocols"
C[74]="保留协议"
E[75]="Add protocols"
C[75]="新增协议"
E[76]="Install TCP brutal"
C[76]="安装 TCP brutal"
E[77]="With sing-box installed, the script exits."
C[77]="已安装 sing-box ，脚本退出"
E[78]="Parameter [ $ERROR_PARAMETER ] error, script exits."
C[78]="[ $ERROR_PARAMETER ] 参数错误，脚本退出"
E[79]="\(3/6\) Please enter the port number of nginx. Must be \${MIN_PORT} - \${MAX_PORT} \(Default is: \${PORT_NGINX_DEFAULT}\):"
C[79]="\(3/6\) 请输入 nginx 端口号，必须是 \${MIN_PORT} - \${MAX_PORT} \(默认为: \${PORT_NGINX_DEFAULT}\):"
E[80]="subscribe"
C[80]="订阅"
E[81]="Adaptive Clash / V2rayN / NekoBox / ShadowRocket / SFI / SFA / SFM Clients"
C[81]="自适应 Clash / V2rayN / NekoBox / ShadowRocket / SFI / SFA / SFM 客户端"
E[82]="template"
C[82]="模版"
E[83]="To uninstall Nginx press [y], it is not uninstalled by default:"
C[83]="如要卸载 Nginx 请按 [y]，默认不卸载:"
E[84]="Set SElinux: enforcing --> disabled"
C[84]="设置 SElinux: enforcing --> disabled"
E[85]="Please input Argo Token or Json ( User can easily obtain the json at https://fscarmen.cloudflare.now.cc ):"
C[85]="请输入 Argo Token 或者 Json ( 用户通过以下网站轻松获取 json: https://fscarmen.cloudflare.now.cc ):"
E[86]="Argo authentication message does not match the rules, neither Token nor Json, script exits. Feedback:[https://github.com/fscarmen/sba/issues]"
C[86]="Argo 认证信息不符合规则，既不是 Token，也是不是 Json，脚本退出，问题反馈:[https://github.com/fscarmen/sba/issues]"
E[87]="Please input the Argo domain (Default is temporary domain if left blank):"
C[87]="请输入 Argo 域名 (如果没有，可以跳过以使用 Argo 临时域名):"
E[88]="Please input the Argo domain (cannot be empty):"
C[88]="请输入 Argo 域名 (不能为空):"
E[89]="( Additional dependencies: nginx )"
C[89]="( 额外依赖: nginx )"
E[90]="Argo tunnel is: \$ARGO_TYPE\\\n The domain is: \$ARGO_DOMAIN"
C[90]="Argo 隧道类型为: \$ARGO_TYPE\\\n 域名是: \$ARGO_DOMAIN"
E[91]="Argo tunnel type:\n 1. Try\n 2. Token or Json"
C[91]="Argo 隧道类型:\n 1. Try\n 2. Token 或者 Json"
E[92]="Change the Argo tunnel (sb -t)"
C[92]="更换 Argo 隧道 (sb -t)"
E[93]="Can't get the temporary tunnel domain, script exits. Feedback:[https://github.com/fscarmen/sing-box/issues]"
C[93]="获取不到临时隧道的域名，脚本退出，问题反馈:[https://github.com/fscarmen/sing-box/issues]"
E[94]="Please bind \[\${ARGO_DOMAIN}] tunnel TYPE to HTTP and URL to \[\localhost:\${PORT_NGINX}] in Cloudflare."
C[94]="请在 Cloudflare 绑定 \[\${ARGO_DOMAIN}] 隧道 TYPE 为 HTTP，URL 为 \[\localhost:\${PORT_NGINX}]"
E[95]="netfilter-persistent installation failed, but the installation progress will not stop. portHopping forwarding rules are temporary rules, reboot may be invalidated."
C[95]="netfilter-persistent安装失败,但安装进度不会停止。PortHopping转发规则为临时规则,重启可能失效"
E[96]="netfilter-persistent is not started, PortHopping forwarding rules cannot be persisted. Reboot the system, the rules will be invalidated, please manually execute [netfilter-persistent save], continue the script does not affect the subsequent configuration."
C[96]="netfilter-persistent未启动，PortHopping转发规则无法持久化，重启系统，规则将会失效，请手动执行 [netfilter-persistent save],继续运行脚本不影响后续配置"
E[97]="Port Hopping/Multiple Ports (Port Hopping) function needs to occupy multiple ports, please make sure that these ports are not listening to other services \n Tip1: The number of ports should not be too many, the recommended number is about 1000, the minimum value: $MIN_HOPPING_PORT, the maximum value: $MAX_HOPPING_PORT.\n Tip2: nat machines have a limited number of ports to listen on, usually 20-30. If setting ports out of the nat range will cause the node to not work, please use with caution!\n This function is not used by default."
C[97]="端口跳跃/多端口(Port Hopping)功能需要占用多个端口，请保证这些端口没有监听其他服务\n Tip1: 端口选择数量不宜过多，推荐1000个左右，最小值:$MIN_HOPPING_PORT，最大值: $MAX_HOPPING_PORT\n Tip2: nat 鸡由于可用于监听的端口有限，一般为20-30个。如设置了不开放的端口会导致节点不通，请慎用！\n 默认不使用该功能"
E[98]="Enter the port range, e.g. 50000:51000. Leave blank to disable:"
C[98]="请输入端口范围，例如 50000:51000，如要禁用请留空:"
E[99]="The \${SING_BOX_SCRIPT} is detected to be installed. Script exits."
C[99]="检测到已安装 \${SING_BOX_SCRIPT}，脚本退出!"

# 自定义字体彩色，read 函数
warning() { echo -e "\033[31m\033[01m$*\033[0m"; }  # 红色
error() { echo -e "\033[31m\033[01m$*\033[0m" && exit 1; } # 红色
info() { echo -e "\033[32m\033[01m$*\033[0m"; }   # 绿色
hint() { echo -e "\033[33m\033[01m$*\033[0m"; }   # 黄色
reading() { read -rp "$(info "$1")" "$2"; }
text() { grep -q '\$' <<< "${E[$*]}" && eval echo "\$(eval echo "\${${L}[$*]}")" || eval echo "\${${L}[$*]}"; }

# 自定义谷歌翻译函数，使用两个翻译 api，如均不能翻译，则返回原英文
translate() {
  [ -n "$@" ] && local EN="$@"
  [ -z "$ZH" ] && local ZH=$(curl -km8 -sSL "https://translate.google.com/translate_a/t?client=any_client_id_works&sl=en&tl=zh&q=${EN//[[:space:]]/%20}" 2>/dev/null | awk -F '"' '{print $2}')
  [ -z "$ZH" ] && local ZH=$(curl -km8 -sSL "https://findmyip.net/api/translate.php?text=${EN//[[:space:]]/%20}" 2>/dev/null | awk -F '"' '{print $16}')
  [ -z "$ZH" ] && echo "$EN" || echo "$ZH"
}

# 检测是否需要启用 Github CDN，如能直接连通，则不使用
check_cdn() {
  [ -n "$GH_PROXY" ] && wget --server-response --quiet --output-document=/dev/null --no-check-certificate --tries=2 --timeout=3 https://raw.githubusercontent.com/fscarmen/sing-box/main/README.md >/dev/null 2>&1 && unset GH_PROXY
}

# 检测是否解锁 chatGPT，以决定是否使用 warp 链式代理或者是 direct out
check_chatgpt() {
  local CHECK_STACK=$1
  local SUPPORT_COUNTRY=(AD AE AF AG AL AM AO AR AT AU AZ BA BB BD BE BF BG BH BI BJ BN BO BR BS BT BW BZ CA CD CF CG CH CI CL CM CO CR CV CY CZ DE DJ DK DM DO DZ EC EE EG ER ES ET FI FJ FM FR GA GB GD GE GH GM GN GQ GR GT GW GY HN HR HT HU ID IE IL IN IQ IS IT JM JO JP KE KG KH KI KM KN KR KW KZ LA LB LC LI LK LR LS LT LU LV LY MA MC MD ME MG MH MK ML MM MN MR MT MU MV MW MX MY MZ NA NE NG NI NL NO NP NR NZ OM PA PE PG PH PK PL PS PT PW PY QA RO RS RW SA SB SC SD SE SG SI SK SL SM SN SO SR SS ST SV SZ TD TG TH TJ TL TM TN TO TR TT TV TW TZ UA UG US UY UZ VA VC VN VU WS YE ZA ZM ZW)
  [[ "${SUPPORT_COUNTRY[@]}" =~ $(wget --no-check-certificate -$CHECK_STACK -qO- --tries=3 --timeout=2 https://chat.openai.com/cdn-cgi/trace | awk -F '=' '/loc/{print $2}') ]] && echo 'unlock' || echo 'ban'
}

# 脚本当天及累计运行次数统计
statistics_of_run-times() {
  local COUNT=$(wget --no-check-certificate -qO- --tries=2 --timeout=2 "https://hits.seeyoufarm.com/api/count/incr/badge.svg?url=https://raw.githubusercontent.com/fscarmen/sing-box/main/sing-box.sh" 2>&1 | grep -m1 -oE "[0-9]+[ ]+/[ ]+[0-9]+") &&
  TODAY=$(awk -F ' ' '{print $1}' <<< "$COUNT") &&
  TOTAL=$(awk -F ' ' '{print $3}' <<< "$COUNT")
}

# 选择中英语言
select_language() {
  if [ -z "$L" ]; then
    if [ -s $WORK_DIR/language ]; then
      L=$(cat $WORK_DIR/language)
    else
      L=E && hint "\n $(text 0) \n" && reading " $(text 24) " LANGUAGE
      [ "$LANGUAGE" = 2 ] && L=C
    fi
  fi
}

# 字母与数字的 ASCII 码值转换
asc() {
  if [[ "$1" = [a-z] ]]; then
    [ "$2" = '++' ] && printf "\\$(printf '%03o' "$[ $(printf "%d" "'$1'") + 1 ]")" || printf "%d" "'$1'"
  else
    [[ "$1" =~ ^[0-9]+$ ]] && printf "\\$(printf '%03o' "$1")"
  fi
}

# 收录一些热心网友和官网的 cdn
input_cdn() {
  echo ""
  for c in "${!CDN_DOMAIN[@]}"; do
    hint " $[c+1]. ${CDN_DOMAIN[c]} "
  done

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
}

# 输入 Nginx 服务端口
input_nginx_port() {
  local NUM=$1
  local PORT_ERROR_TIME=6
  # 生成 1000 - 65535 随机默认端口数
  local PORT_NGINX_DEFAULT=$(shuf -i ${MIN_PORT}-${MAX_PORT} -n 1)
  while true; do
    [[ "$PORT_ERROR_TIME" > 1 && "$PORT_ERROR_TIME" < 6 ]] && unset IN_USED PORT_NGINX
    (( PORT_ERROR_TIME-- )) || true
    if [ "$PORT_ERROR_TIME" = 0 ]; then
      error "\n $(text 3) \n"
    else
      [ -z "$PORT_NGINX" ] && reading "\n $(text 79) " PORT_NGINX
    fi
    PORT_NGINX=${PORT_NGINX:-"$PORT_NGINX_DEFAULT"}
    if [[ "$PORT_NGINX" =~ ^[1-9][0-9]{1,4}$ && "$PORT_NGINX" -ge "$MIN_PORT" && "$PORT_NGINX" -le "$MAX_PORT" ]]; then
      ss -nltup | grep -q ":$PORT_NGINX" && warning "\n $(text 44) \n" || break
    fi
  done
}

# 输入 hysteria2 跳跃端口
input_hopping_port() {
  local HOPPING_ERROR_TIME=6
  until [ -n "$IS_HOPPING" ]; do
    (( HOPPING_ERROR_TIME-- )) || true
    case "$HOPPING_ERROR_TIME" in
      0 )
        error "\n $(text 3) \n"
        ;;
      5 )
        hint "\n $(text 97) \n" && reading " $(text 98) " PORT_HOPPING_RANGE
        ;;
      * )
        reading " $(text 98) " PORT_HOPPING_RANGE
    esac
    if [[ "${PORT_HOPPING_RANGE//-/:}" =~ ^[1-6][0-9]{4}:[1-6][0-9]{4}$ ]]; then
      # 为防止输入错误，把 - 改为 : ，比如  10000-11000 改为 10000:11000
      PORT_HOPPING_RANGE=${PORT_HOPPING_RANGE//-/:}
      PORT_HOPPING_START=${PORT_HOPPING_RANGE%:*}
      PORT_HOPPING_END=${PORT_HOPPING_RANGE#*:}
      [[ "$PORT_HOPPING_START" < "$PORT_HOPPING_END" && "$PORT_HOPPING_START" -ge "$MIN_HOPPING_PORT" && "$PORT_HOPPING_END" -le "$MAX_HOPPING_PORT" ]] && IS_HOPPING=is_hopping || warning "\n $(text 36) "
    elif [[ -z "$PORT_HOPPING_RANGE" || "${PORT_HOPPING_RANGE,,}" =~ ^(n|no)$ ]]; then
      IS_HOPPING=no_hoppinng
    else
      warning "\n $(text 36) "
    fi
  done
}

# 输入 Argo 域名和认证信息
input_argo_auth() {
  local IS_CHANGE_ARGO=$1
  [ -n "$IS_CHANGE_ARGO" ] && local EMPTY_ERROR_TIME=5
  local DOMAIN_ERROR_TIME=6

  # 处理可能输入的错误，去掉开头和结尾的空格，去掉最后的 :
  if [ "$IS_CHANGE_ARGO" = 'is_change_argo' ]; then
    until [ -n "$ARGO_DOMAIN" ]; do
      (( EMPTY_ERROR_TIME-- )) || true
      [ "$EMPTY_ERROR_TIME" = 0 ] && error "\n $(text 3) \n"
      reading "\n $(text 88) " ARGO_DOMAIN
      [ -n "$IS_CHANGE_ARGO" ] && ARGO_DOMAIN=$(sed 's/[ ]*//g; s/:[ ]*//' <<< "$ARGO_DOMAIN")
    done
  elif [ "$NONINTERACTIVE_INSTALL" != 'noninteractive_install' ]; then
    [ -z "$ARGO_DOMAIN" ] && reading "\n $(text 87) " ARGO_DOMAIN
    ARGO_DOMAIN=$(sed 's/[ ]*//g; s/:[ ]*//' <<< "$ARGO_DOMAIN")
  fi

  if [[ -z "$ARGO_DOMAIN" && ( "$ARGO_DOMAIN" =~ trycloudflare\.com$ || "$IS_CHANGE_ARGO" = 'is_add_protocols' || "$IS_CHANGE_ARGO" = 'is_install' || "$NONINTERACTIVE_INSTALL" = 'noninteractive_install' ) ]]; then
    ARGO_RUNS="$WORK_DIR/cloudflared tunnel --edge-ip-version auto --no-autoupdate --url http://localhost:$PORT_NGINX"
  elif [ -n "${ARGO_DOMAIN}" ]; then
    if [ -z "${ARGO_AUTH}" ]; then
      until [[ "$ARGO_AUTH" =~ TunnelSecret || "$ARGO_AUTH" =~ ^[A-Z0-9a-z=]{120,250}$ || "$ARGO_AUTH" =~ .*cloudflared.*service[[:space:]]+install[[:space:]]+[A-Z0-9a-z=]{1,100} ]]; do
        [ "$DOMAIN_ERROR_TIME" != 6 ] && warning "\n $(text 86) \n"
      (( DOMAIN_ERROR_TIME-- )) || true
        [ "$DOMAIN_ERROR_TIME" != 0 ] && reading "\n $(text 85) " ARGO_AUTH || error "\n $(text 3) \n"
      done
    fi

    # 根据 ARGO_AUTH 的内容，自行判断是 Json 还是 Token
    if [[ "$ARGO_AUTH" =~ TunnelSecret ]]; then
      ARGO_TYPE=is_json_argo
      ARGO_JSON=${ARGO_AUTH//[ ]/}
      [ "$IS_CHANGE_ARGO" = 'is_install' ] && export_argo_json_file $TEMP_DIR || export_argo_json_file $WORK_DIR
      ARGO_RUNS="$WORK_DIR/cloudflared tunnel --edge-ip-version auto --config $WORK_DIR/tunnel.yml run"
    elif [[ "$ARGO_AUTH" =~ ^[A-Z0-9a-z=]{120,250}$ ]]; then
      ARGO_TYPE=is_token_argo
      ARGO_TOKEN=$ARGO_AUTH
      ARGO_RUNS="$WORK_DIR/cloudflared tunnel --edge-ip-version auto run --token ${ARGO_TOKEN}"
    elif [[ "$ARGO_AUTH" =~ .*cloudflared.*service[[:space:]]+install[[:space:]]+[A-Z0-9a-z=]{1,100} ]]; then
      ARGO_TYPE=is_token_argo
      ARGO_TOKEN=$(awk -F ' ' '{print $NF}' <<< "$ARGO_AUTH")
      ARGO_RUNS="$WORK_DIR/cloudflared tunnel --edge-ip-version auto run --token ${ARGO_TOKEN}"
    fi
  fi
}

# 更换 Argo 隧道类型
change_argo() {
  check_install
  if [ "${STATUS[0]}" =  "$(text 26)" ]; then
    error "\n $(text 39) "
  elif [ "${STATUS[1]}" = "$(text 26)" ]; then
    error "\n $(text 61) "
  fi

  case $(grep "ExecStart=" /etc/systemd/system/argo.service) in
    *--config* )
      ARGO_TYPE='Json'
      ;;
    *--token* )
      ARGO_TYPE='Token'
      ;;
    * )
      ARGO_TYPE='Try'
      cmd_systemctl enable argo && sleep 2 && [ "$(systemctl is-active argo)" = 'active' ] && fetch_quicktunnel_domain
  esac

  fetch_nodes_value
  hint "\n $(text 90) \n"
  unset ARGO_DOMAIN
  hint " $(text 91) \n" && reading " $(text 24) " CHANGE_TO
    case "$CHANGE_TO" in
      1 )
        cmd_systemctl disable argo
        [ -s $WORK_DIR/tunnel.json ] && rm -f $WORK_DIR/tunnel.{json,yml}
        sed -i "s@ExecStart=.*@ExecStart=$WORK_DIR/cloudflared tunnel --edge-ip-version auto --no-autoupdate --url http://localhost:$PORT_NGINX@g" /etc/systemd/system/argo.service
        ;;
      2 )
        [ -s $WORK_DIR/tunnel.json ] && rm -f $WORK_DIR/tunnel.{json,yml}
        input_argo_auth is_change_argo
        cmd_systemctl disable argo
        if [ -n "$ARGO_TOKEN" ]; then
          sed -i "s@ExecStart=.*@ExecStart=$WORK_DIR/cloudflared tunnel --edge-ip-version auto run --token ${ARGO_TOKEN}@g" /etc/systemd/system/argo.service
        elif [ -n "$ARGO_JSON" ]; then
          sed -i "s@ExecStart=.*@ExecStart=$WORK_DIR/cloudflared tunnel --edge-ip-version auto --config $WORK_DIR/tunnel.yml run@g" /etc/systemd/system/argo.service
        fi
        [ -s $WORK_DIR/conf/17_${NODE_TAG[6]}_inbounds.json ] && sed -i "s/VMESS_HOST_DOMAIN.*/VMESS_HOST_DOMAIN\": \"$ARGO_DOMAIN\"/" $WORK_DIR/conf/17_${NODE_TAG[6]}_inbounds.json
        [ -s $WORK_DIR/conf/18_${NODE_TAG[7]}_inbounds.json ] && sed -i "s/\"server_name\":.*/\"server_name\": \"$ARGO_DOMAIN\",/" $WORK_DIR/conf/18_${NODE_TAG[7]}_inbounds.json
        ;;
      * )
        exit 0
    esac

  cmd_systemctl enable argo
  fetch_nodes_value
  export_nginx_conf_file
  export_list
}

check_root() {
  [ "$(id -u)" != 0 ] && error "\n $(text 43) \n"
}

# 判断处理器架构
check_arch() {
  case "$(uname -m)" in
    aarch64|arm64 )
      SING_BOX_ARCH=arm64; JQ_ARCH=arm64; QRENCODE_ARCH=arm64; ARGO_ARCH=arm64
      ;;
    x86_64|amd64 )
      [[ "$(awk -F ':' '/flags/{print $2; exit}' /proc/cpuinfo)" =~ avx2 ]] && SING_BOX_ARCH=amd64v3 || SING_BOX_ARCH=amd64; JQ_ARCH=amd64; QRENCODE_ARCH=amd64; ARGO_ARCH=amd64
      ;;
    armv7l )
      SING_BOX_ARCH=armv7; JQ_ARCH=armhf; QRENCODE_ARCH=arm; ARGO_ARCH=amd64
      ;;
    * )
      error " $(text 25) "
  esac
}

# 查安装及运行状态，下标0: sing-box，下标1: argo，下标2：docker；状态码: 26 未安装， 27 已安装未运行， 28 运行中
check_install() {
  [[ "$IS_SUB" = 'is_sub' || -s $WORK_DIR/subscribe/qr ]] && IS_SUB=is_sub || IS_SUB=no_sub
  if ls $WORK_DIR/conf/*${NODE_TAG[1]}_inbounds.json >/dev/null 2>&1; then
    check_port_hopping_nat
    [ -n "$PORT_HOPPING_END" ] && IS_HOPPING=is_hopping || IS_HOPPING=no_hopping
  fi

  # 检测是否安装其他 sing-box systemd 状态，和是否其他一键脚本
  if [ -s /etc/systemd/system/sing-box.service ]; then
    SYSTEMD_EXECSTART=$(grep '^ExecStart=' /etc/systemd/system/sing-box.service)
    case "$SYSTEMD_EXECSTART" in
      'ExecStart=/etc/sing-box/sing-box run -C /etc/sing-box/conf/' )
        [ "$(systemctl is-active sing-box)" = 'active' ] && STATUS[0]=$(text 28) || STATUS[0]=$(text 27)
        ;;
      'ExecStart=/etc/v2ray-agent/sing-box/sing-box run -c /etc/v2ray-agent/sing-box/conf/config.json' )
        SING_BOX_SCRIPT='mack-a/v2ray-agent' && error "\n $(text 99) \n"
        ;;
      'ExecStart=/etc/s-box/sing-box run -c /etc/s-box/sb.json' )
        SING_BOX_SCRIPT='yonggekkk/sing-box_hysteria2_tuic_argo_reality' && error "\n $(text 99) \n"
        ;;
      'ExecStart=/usr/local/s-ui/bin/runSingbox.sh' )
        SING_BOX_SCRIPT='alireza0/s-ui' && error "\n $(text 99) \n"
        ;;
      'ExecStart=/usr/local/bin/sing-box run -c /usr/local/etc/sing-box/config.json' )
        SING_BOX_SCRIPT='FranzKafkaYu/sing-box-yes' && error "\n $(text 99) \n"
        ;;
      * )
        SING_BOX_SCRIPT='Unknown or customized sing-box' && error "\n $(text 99) \n"
    esac
  elif [ -s /lib/systemd/system/sing-box.service ]; then
    SYSTEMD_EXECSTART=$(grep '^ExecStart=' /lib/systemd/system/sing-box.service)
    case "$SYSTEMD_EXECSTART" in
      'ExecStart=/etc/sing-box/bin/sing-box run -c /etc/sing-box/config.json -C /etc/sing-box/conf' )
        SING_BOX_SCRIPT='233boy/sing-box' && error "\n $(text 99) \n"
        ;;
      * )
        SING_BOX_SCRIPT='Unknown or customized sing-box' && error "\n $(text 99) \n"
    esac
  else
    STATUS[0]=$(text 26)
  fi

  if [ "${STATUS[0]}" = "$(text 26)" ] && [ ! -s $WORK_DIR/sing-box ]; then
    {
    local VERSION_LATEST=$(wget --no-check-certificate --tries=2 --timeout=3 -qO- ${GH_PROXY}https://api.github.com/repos/SagerNet/sing-box/releases | awk -F '["v-]' '/tag_name/{print $5}' | sort -Vr | sed -n '1p')
    local ONLINE=$(wget --no-check-certificate --tries=2 --timeout=3 -qO- ${GH_PROXY}https://api.github.com/repos/SagerNet/sing-box/releases | awk -F '["v]' -v var="tag_name.*$VERSION_LATEST" '$0 ~ var {print $5; exit}')
    ONLINE=${ONLINE:-'1.10.0-alpha.13'}
    wget --no-check-certificate --continue ${GH_PROXY}https://github.com/SagerNet/sing-box/releases/download/v$ONLINE/sing-box-$ONLINE-linux-$SING_BOX_ARCH.tar.gz -qO- | tar xz -C $TEMP_DIR sing-box-$ONLINE-linux-$SING_BOX_ARCH/sing-box >/dev/null 2>&1
    [ -s $TEMP_DIR/sing-box-$ONLINE-linux-$SING_BOX_ARCH/sing-box ] && mv $TEMP_DIR/sing-box-$ONLINE-linux-$SING_BOX_ARCH/sing-box $TEMP_DIR
    wget --no-check-certificate --continue -qO $TEMP_DIR/jq ${GH_PROXY}https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-$JQ_ARCH >/dev/null 2>&1 && chmod +x $TEMP_DIR/jq >/dev/null 2>&1
    wget --no-check-certificate --continue -qO $TEMP_DIR/qrencode ${GH_PROXY}https://github.com/fscarmen/client_template/raw/main/qrencode-go/qrencode-go-linux-$QRENCODE_ARCH >/dev/null 2>&1 && chmod +x $TEMP_DIR/qrencode >/dev/null 2>&1
    }&
  fi

  if [ "$NONINTERACTIVE_INSTALL" != 'noninteractive_install' ]; then
    STATUS[1]=$(text 26) && IS_ARGO=no_argo && [ -s /etc/systemd/system/argo.service ] && IS_ARGO=is_argo && STATUS[1]=$(text 27) && [ "$(systemctl is-active argo)" = 'active' ] && STATUS[1]=$(text 28)
  fi
  if [ -s /etc/systemd/system/argo.service ]; then
    local ARGO_CONTENT=$(cat /etc/systemd/system/argo.service)
    if grep -q '\--token' <<< "$ARGO_CONTENT"; then
      ARGO_TYPE=is_token_argo
    elif grep -q '\--config' <<< "$ARGO_CONTENT"; then
      ARGO_TYPE=is_json_argo
    elif grep -q '\--url' <<< "$ARGO_CONTENT"; then
      ARGO_TYPE=is_quicktunnel_argo
    fi
  fi
  [[ "${STATUS[1]}" = "$(text 26)" || "$NONINTERACTIVE_INSTALL" = 'noninteractive_install' ]] && [ ! -s $WORK_DIR/cloudflared ] && { wget --no-check-certificate -qO $TEMP_DIR/cloudflared ${GH_PROXY}https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$ARGO_ARCH >/dev/null 2>&1 && chmod +x $TEMP_DIR/cloudflared >/dev/null 2>&1; }&
}

# 检测 sing-box 的状态
check_sing-box_status() {
  case "${STATUS[0]}" in
    "$(text 26)" )
      error "\n Sing-box $(text 28) $(text 38) \n"
      ;;
    "$(text 27)" )
      cmd_systemctl enable sing-box
      [ "$(systemctl is-active sing-box)" = 'active' ] && info "\n Sing-box $(text 28) $(text 37) \n" || error "\n Sing-box $(text 28) $(text 38) \n"
      ;;
    "$(text 28)" )
      info "\n Sing-box $(text 28) $(text 37) \n"
  esac
}

# 检测 Argo 的状态
check_argo_status() {
  case "${STATUS[1]}" in
    "$(text 26)" )
      error "\n Argo $(text 28) $(text 38) \n"
      ;;
    "$(text 27)" )
      cmd_systemctl enable argo
      [ "$(systemctl is-active argo)" = 'active' ] && info "\n Argo $(text 28) $(text 37) \n" || error "\n Argo $(text 28) $(text 38) \n"
      ;;
    "$(text 28)" )
      info "\n Argo $(text 28) $(text 37) \n"
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
    elif [ "$IS_CENTOS" = 'CentOS7' ]; then
      systemctl enable --now $APP
      [ "$APP" = 'sing-box' ] && [[ "${IS_SUB}" = 'is_sub' || "${IS_ARGO}" = 'is_argo' ]] && $(type -p nginx) -c $WORK_DIR/nginx.conf
    else
      systemctl enable --now $APP
    fi
  elif [ "$ENABLE_DISABLE" = 'disable' ]; then
    if [ "$SYSTEM" = 'Alpine' ]; then
      systemctl stop $APP
      [ "$APP" = 'sing-box' ] && [[ "${IS_SUB}" = 'is_sub' || "${IS_ARGO}" = 'is_argo' ]] && [ -s $WORK_DIR/nginx.conf ] && ss -nltp | grep $(awk '/listen/{print $2; exit}' $WORK_DIR/nginx.conf) | tr ',' '\n' | awk -F '=' '/pid/{print $2}' | sort -u | xargs kill -15 >/dev/null 2>&1
      rm -f /etc/local.d/$APP.start
    elif [ "$IS_CENTOS" = 'CentOS7' ]; then
      systemctl disable --now $APP
      [ "$APP" = 'sing-box' ] && [[ "${IS_SUB}" = 'is_sub' || "${IS_ARGO}" = 'is_argo' ]] && [ -s $WORK_DIR/nginx.conf ] && ss -nltp | grep $(awk '/listen/{print $2; exit}' $WORK_DIR/nginx.conf) | tr ',' '\n' | awk -F '=' '/pid/{print $2}' | sort -u | xargs kill -15 >/dev/null 2>&1
    else
      systemctl disable --now $APP
    fi
  fi
}

check_system_info() {
  # 判断虚拟化
  if [ -x "$(type -p systemd-detect-virt)" ]; then
    VIRT=$(systemd-detect-virt)
  elif [ -x "$(type -p hostnamectl)" ]; then
    VIRT=$(hostnamectl | awk '/Virtualization/{print $NF}')
  elif [ -x "$(type -p virt-what)" ]; then
    VIRT=$(virt-what)
  fi

  [ -s /etc/os-release ] && SYS="$(awk -F '"' 'tolower($0) ~ /pretty_name/{print $2}' /etc/os-release)"
  [[ -z "$SYS" && -x "$(type -p hostnamectl)" ]] && SYS="$(hostnamectl | awk -F ': ' 'tolower($0) ~ /operating system/{print $2}')"
  [[ -z "$SYS" && -x "$(type -p lsb_release)" ]] && SYS="$(lsb_release -sd)"
  [[ -z "$SYS" && -s /etc/lsb-release ]] && SYS="$(awk -F '"' 'tolower($0) ~ /distrib_description/{print $2}' /etc/lsb-release)"
  [[ -z "$SYS" && -s /etc/redhat-release ]] && SYS="$(cat /etc/redhat-release)"
  [[ -z "$SYS" && -s /etc/issue ]] && SYS="$(sed -E '/^$|^\\/d' /etc/issue | awk -F '\\' '{print $1}' | sed 's/[ ]*$//g')"

  REGEX=("debian" "ubuntu" "centos|red hat|kernel|alma|rocky" "arch linux" "alpine" "fedora")
  RELEASE=("Debian" "Ubuntu" "CentOS" "Arch" "Alpine" "Fedora")
  EXCLUDE=("")
  MAJOR=("9" "16" "7" "3" "" "37")
  PACKAGE_UPDATE=("apt -y update" "apt -y update" "yum -y update --skip-broken" "pacman -Sy" "apk update -f" "dnf -y update")
  PACKAGE_INSTALL=("apt -y install" "apt -y install" "yum -y install" "pacman -S --noconfirm" "apk add --no-cache" "dnf -y install")
  PACKAGE_UNINSTALL=("apt -y autoremove" "apt -y autoremove" "yum -y autoremove" "pacman -Rcnsu --noconfirm" "apk del -f" "dnf -y autoremove")

  for int in "${!REGEX[@]}"; do
    [[ "${SYS,,}" =~ ${REGEX[int]} ]] && SYSTEM="${RELEASE[int]}" && break
  done

  # 针对各厂商的订制系统
  if [ -z "$SYSTEM" ]; then
    [ -x "$(type -p yum)" ] && int=2 && SYSTEM='CentOS' || error " $(text 5) "
  fi

  # 先排除 EXCLUDE 里包括的特定系统，其他系统需要作大发行版本的比较
  for ex in "${EXCLUDE[@]}"; do [[ ! "{$SYS,,}"  =~ $ex ]]; done &&
  [[ "$(echo "$SYS" | sed "s/[^0-9.]//g" | cut -d. -f1)" -lt "${MAJOR[int]}" ]] && error " $(text 6) "

  # 针对部分系统作特殊处理
  [ "$SYSTEM" = 'CentOS' ] && IS_CENTOS="CentOS$(echo "$SYS" | sed "s/[^0-9.]//g" | cut -d. -f1)"
}

# 删除端口跳跃
del_port_hopping_nat(){
  check_port_hopping_nat
  if [ "$SYSTEM" = 'Alpine' ]; then
    iptables --table nat -D PREROUTING -p udp --dport ${PORT_HOPPING_START}:${PORT_HOPPING_END} -m comment --comment "NAT ${PORT_HOPPING_START}:${PORT_HOPPING_END} to ${PORT_HOPPING_TARGET} (Sing-box Family Bucket)" -j DNAT --to-destination :${PORT_HOPPING_TARGET} 2>/dev/null
    ip6tables --table nat -D PREROUTING -p udp --dport ${PORT_HOPPING_START}:${PORT_HOPPING_END} -m comment --comment "NAT ${PORT_HOPPING_START}:${PORT_HOPPING_END} to ${PORT_HOPPING_TARGET} (Sing-box Family Bucket)" -j DNAT --to-destination :${PORT_HOPPING_TARGET} 2>/dev/null
  elif [ "$(systemctl is-active firewalld)" = 'active' ]; then
    firewall-cmd --permanent --remove-forward-port=port=${PORT_HOPPING_START}-${PORT_HOPPING_END}:proto=udp:toport=${PORT_HOPPING_TARGET} >/dev/null 2>&1
    firewall-cmd --reload >/dev/null 2>&1
  else
    iptables --table nat -D PREROUTING -p udp --dport ${PORT_HOPPING_START}:${PORT_HOPPING_END} -m comment --comment "NAT ${PORT_HOPPING_START}:${PORT_HOPPING_END} to ${PORT_HOPPING_TARGET} (Sing-box Family Bucket)" -j DNAT --to-destination :${PORT_HOPPING_TARGET} 2>/dev/null
    ip6tables --table nat -D PREROUTING -p udp --dport ${PORT_HOPPING_START}:${PORT_HOPPING_END} -m comment --comment "NAT ${PORT_HOPPING_START}:${PORT_HOPPING_END} to ${PORT_HOPPING_TARGET} (Sing-box Family Bucket)" -j DNAT --to-destination :${PORT_HOPPING_TARGET} 2>/dev/null
    [ "$(systemctl is-active netfilter-persistent)" = 'active' ] && netfilter-persistent save 2>/dev/null
  fi
}

# 添加端口跳跃
add_port_hopping_nat() {
  local PORT_HOPPING_START=$1
  local PORT_HOPPING_END=$2
  local PORT_HOPPING_TARGET=$3

  # 检测防火墙依赖和状态
  if [ "$SYSTEM" = 'Alpine' ]; then
    # 添加防火墙规则
    iptables --table nat -A PREROUTING -p udp --dport ${PORT_HOPPING_START}:${PORT_HOPPING_END} -m comment --comment "NAT ${PORT_HOPPING_START}:${PORT_HOPPING_END} to ${PORT_HOPPING_TARGET} (Sing-box Family Bucket)" -j DNAT --to-destination :${PORT_HOPPING_TARGET} 2>/dev/null
    ip6tables --table nat -A PREROUTING -p udp --dport ${PORT_HOPPING_START}:${PORT_HOPPING_END} -m comment --comment "NAT ${PORT_HOPPING_START}:${PORT_HOPPING_END} to ${PORT_HOPPING_TARGET} (Sing-box Family Bucket)" -j DNAT --to-destination :${PORT_HOPPING_TARGET} 2>/dev/null

    # 将 iptables, ip6tables 添加到默认运行级别
    rc-update show default | grep -q 'iptables' || rc-update add iptables >/dev/null 2>&1
    rc-update show default | grep -q 'ip6tables' || rc-update add ip6tables >/dev/null 2>&1
    rc-update show default | grep -q 'iptables' && rc-update show default | grep -q 'ip6tables' || warning "\n $(text 96) \n"

    # 保存当前的 iptables, ip6tables 规则集，以便在开机时恢复
    rc-service iptables save >/dev/null 2>&1
    rc-service ip6tables save >/dev/null 2>&1

  elif [ -x "$(type -p firewalld)" ]; then
    [ "$(systemctl is-active firewalld)" != 'active' ] && systemctl enable --now firewalld >/dev/null 2>&1
    if [ "$(firewall-cmd --query-masquerade --permanent)" != 'yes' ] ; then
      firewall-cmd --add-masquerade --permanent >/dev/null 2>&1
      firewall-cmd --reload >/dev/null 2>&1
      [ "$(firewall-cmd --query-masquerade --permanent)" = 'yes' ] && info "\n firewalld masquerade $(text 28) $(text 37) \n" || warning "\n firewalld masquerade $(text 28) $(text 38) \n"
    fi

    # 添加防火墙规则
    firewall-cmd --add-forward-port=port=$PORT_HOPPING_START-$PORT_HOPPING_END:proto=udp:toport=${PORT_HOPPING_TARGET} --permanent >/dev/null 2>&1
    firewall-cmd --reload >/dev/null 2>&1

  else
    if [ ! -x "$(type -p netfilter-persistent)" ]; then
      info "\n $(text 7) iptables-persistent"
      ${PACKAGE_INSTALL[int]} iptables-persistent >/dev/null 2>&1
    fi
    [ -x "$(type -p netfilter-persistent)" ] || warning "\n $(text 95) \n"

    # 添加防火墙规则
    iptables --table nat -A PREROUTING -p udp --dport ${PORT_HOPPING_START}:${PORT_HOPPING_END} -m comment --comment "NAT ${PORT_HOPPING_START}:${PORT_HOPPING_END} to ${PORT_HOPPING_TARGET} (Sing-box Family Bucket)" -j DNAT --to-destination :${PORT_HOPPING_TARGET} 2>/dev/null
    ip6tables --table nat -A PREROUTING -p udp --dport ${PORT_HOPPING_START}:${PORT_HOPPING_END} -m comment --comment "NAT ${PORT_HOPPING_START}:${PORT_HOPPING_END} to ${PORT_HOPPING_TARGET} (Sing-box Family Bucket)" -j DNAT --to-destination :${PORT_HOPPING_TARGET} 2>/dev/null

    # 保存当前的 iptables, ip6tables 规则集，以便在开机时恢复
    [ "$(systemctl is-active netfilter-persistent)" != 'active' ] && warning "\n $(text 96) \n" || netfilter-persistent save 2>/dev/null
  fi
}

# 查端口跳跃的 dnat 端口
check_port_hopping_nat() {
  PORT_HOPPING_TARGET=$(awk -F [:,] '/"listen_port"/{print $2}' $WORK_DIR/conf/*${NODE_TAG[1]}_inbounds.json)
  if [ "$SYSTEM" = 'Alpine' ]; then
    local IPTABLES_PREROUTING_LIST=$(iptables --table nat --list-rules PREROUTING 2>/dev/null | grep 'Sing-box Family Bucket')
    [ -n "$IPTABLES_PREROUTING_LIST" ] && PORT_HOPPING_RANGE=$(awk '{for (i=0; i<NF; i++) if ($i=="--dport") {print $(i+1); exit}}' <<< "$IPTABLES_PREROUTING_LIST") && PORT_HOPPING_TARGET=$(awk '{for (i=0; i<NF; i++) if ($i=="to") {print $(i+1); exit}}' <<< "$IPTABLES_PREROUTING_LIST")
    [ -n "$PORT_HOPPING_RANGE" ] && PORT_HOPPING_START=${PORT_HOPPING_RANGE%:*} && PORT_HOPPING_END=${PORT_HOPPING_RANGE#*:}
  elif [ "$(systemctl is-active firewalld)" = 'active' ]; then
    local FIREWALL_LIST=$(firewall-cmd --list-all --permanent | grep "toport=${PORT_HOPPING_TARGET}")
    [ -n "$FIREWALL_LIST" ] && PORT_HOPPING_START=$(sed "s/.*port=\([^-]\+\)-.*toport.*/\1/" <<< "$FIREWALL_LIST") &&
    PORT_HOPPING_END=$(sed "s/.*port=$PORT_HOPPING_START-\([^:]\+\):.*toport.*/\1/" <<< "$FIREWALL_LIST") &&
    PORT_HOPPING_TARGET=$(sed "s/.*toport=\([^:]\+\):.*/\1/" <<< "$FIREWALL_LIST")
  else
    local IPTABLES_PREROUTING_LIST=$(iptables --table nat --list-rules PREROUTING 2>/dev/null | grep 'Sing-box Family Bucket')
    [ -n "$IPTABLES_PREROUTING_LIST" ] && PORT_HOPPING_RANGE=$(awk '{for (i=0; i<NF; i++) if ($i=="--dport") {print $(i+1); exit}}' <<< "$IPTABLES_PREROUTING_LIST") && PORT_HOPPING_TARGET=$(awk '{for (i=0; i<NF; i++) if ($i=="to") {print $(i+1); exit}}' <<< "$IPTABLES_PREROUTING_LIST")
    [ -n "$PORT_HOPPING_RANGE" ] && PORT_HOPPING_START=${PORT_HOPPING_RANGE%:*} && PORT_HOPPING_END=${PORT_HOPPING_RANGE#*:}
  fi
}

# 检测 IPv4 IPv6 信息
check_system_ip() {
  local DEFAULT_LOCAL_INTERFACE4=$(ip -4 route show default | awk '/default/ {for (i=0; i<NF; i++) if ($i=="dev") {print $(i+1); exit}}')
  local DEFAULT_LOCAL_INTERFACE6=$(ip -6 route show default | awk '/default/ {for (i=0; i<NF; i++) if ($i=="dev") {print $(i+1); exit}}')
  if [ -n "$DEFAULT_LOCAL_INTERFACE" ]; then
    local DEFAULT_LOCAL_IP4=$(ip -4 addr show $DEFAULT_LOCAL_INTERFACE | sed -n 's#.*inet \([^/]\+\)/[0-9]\+.*global.*#\1#gp')
    local DEFAULT_LOCAL_IP6=$(ip -6 addr show $DEFAULT_LOCAL_INTERFACE | sed -n 's#.*inet6 \([^/]\+\)/[0-9]\+.*global.*#\1#gp')
    [ -n "$DEFAULT_LOCAL_IP4" ] && local BIND_ADDRESS4="--bind-address=$DEFAULT_LOCAL_IP4"
    [ -n "$DEFAULT_LOCAL_IP6" ] && local BIND_ADDRESS6="--bind-address=$DEFAULT_LOCAL_IP6"
  fi

  IP4=$(wget -4 $BIND_ADDRESS4 -qO- --no-check-certificate --user-agent=Mozilla --tries=2 --timeout=1 http://ip-api.com/json/) &&
  WAN4=$(expr "$IP4" : '.*query\":[ ]*\"\([^"]*\).*') &&
  COUNTRY4=$(expr "$IP4" : '.*country\":[ ]*\"\([^"]*\).*') &&
  ASNORG4=$(expr "$IP4" : '.*isp\":[ ]*\"\([^"]*\).*') &&
  [[ "$L" = C && -n "$COUNTRY4" ]] && COUNTRY4=$(translate "$COUNTRY4")

  IP6=$(wget -6 $BIND_ADDRESS6 -qO- --no-check-certificate --user-agent=Mozilla --tries=2 --timeout=1 https://api.ip.sb/geoip) &&
  WAN6=$(expr "$IP6" : '.*ip\":[ ]*\"\([^"]*\).*') &&
  COUNTRY6=$(expr "$IP6" : '.*country\":[ ]*\"\([^"]*\).*') &&
  ASNORG6=$(expr "$IP6" : '.*isp\":[ ]*\"\([^"]*\).*') &&
  [[ "$L" = C && -n "$COUNTRY6" ]] && COUNTRY6=$(translate "$COUNTRY6")
}

# 输入起始 port 函数
input_start_port() {
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
    if [[ "$START_PORT" =~ ^[1-9][0-9]{2,4}$ && "$START_PORT" -ge "$MIN_PORT" && "$START_PORT" -le "$MAX_PORT" ]]; then
      for port in $(eval echo {$START_PORT..$[START_PORT+NUM-1]}); do
      ss -nltup | grep -q ":$port" && IN_USED+=("$port")
      done
      [ "${#IN_USED[*]}" -eq 0 ] && break || warning "\n $(text 44) \n"
    fi
  done
}

# 定义 Sing-box 变量
sing-box_variables() {
  if grep -qi 'cloudflare' <<< "$ASNORG4$ASNORG6"; then
    if grep -qi 'cloudflare' <<< "$ASNORG6" && [ -n "$WAN4" ] && ! grep -qi 'cloudflare' <<< "$ASNORG4"; then
      SERVER_IP_DEFAULT=$WAN4
    elif grep -qi 'cloudflare' <<< "$ASNORG4" && [ -n "$WAN6" ] && ! grep -qi 'cloudflare' <<< "$ASNORG6"; then
      SERVER_IP_DEFAULT=$WAN6
    else
      local a=6
      until [ -n "$SERVER_IP" ]; do
        ((a--)) || true
        [ "$a" = 0 ] && error "\n $(text 3) \n"
        reading "\n $(text 46) " SERVER_IP
      done
    fi
  elif [ -n "$WAN4" ]; then
    SERVER_IP_DEFAULT=$WAN4
  elif [ -n "$WAN6" ]; then
    SERVER_IP_DEFAULT=$WAN6
  fi

  # 检测是否解锁 chatGPT
  CHAT_GPT_OUT_V4=warp-IPv4-out; CHAT_GPT_OUT_V6=warp-IPv6-out;
  [ "$(check_chatgpt ${DOMAIN_STRATEG: -1})" = 'unlock' ] && CHAT_GPT_OUT_V4=direct && CHAT_GPT_OUT_V6=direct

  # 选择安装的协议，由于选项 a 为全部协议，所以选项数不是从 a 开始，而是从 b 开始，处理输入：把大写全部变为小写，把不符合的选项去掉，把重复的选项合并
  MAX_CHOOSE_PROTOCOLS=$(asc $[CONSECUTIVE_PORTS+96+1])
  if [ -z "$CHOOSE_PROTOCOLS" ]; then
    hint "\n $(text 49) "
    for e in "${!PROTOCOL_LIST[@]}"; do
      [[ "$e" =~ '6'|'7' ]] && hint " $(asc $[e+98]). ${PROTOCOL_LIST[e]} " || hint " $(asc $[e+98]). ${PROTOCOL_LIST[e]} "
    done
    reading "\n $(text 24) " CHOOSE_PROTOCOLS
  fi

  # 对选择协议的输入处理逻辑：先把所有的大写转为小写，并把所有没有去选项剔除掉，最后按输入的次序排序。如果选项为 a(all) 和其他选项并存，将会忽略 a，如 abc 则会处理为 bc
  [[ ! "${CHOOSE_PROTOCOLS,,}" =~ [b-$MAX_CHOOSE_PROTOCOLS] ]] && INSTALL_PROTOCOLS=($(eval echo {b..$MAX_CHOOSE_PROTOCOLS})) || INSTALL_PROTOCOLS=($(grep -o . <<< "$CHOOSE_PROTOCOLS" | sed "/[^b-$MAX_CHOOSE_PROTOCOLS]/d" | awk '!seen[$0]++'))

  # 显示选择协议及其次序，输入开始端口号
  if [ -z "$START_PORT" ]; then
    hint "\n $(text 60) "
    for w in "${!INSTALL_PROTOCOLS[@]}"; do
      [ "$w" -ge 9 ] && hint " $[w+1]. ${PROTOCOL_LIST[$(($(asc ${INSTALL_PROTOCOLS[w]}) - 98))]} " || hint " $[w+1] . ${PROTOCOL_LIST[$(($(asc ${INSTALL_PROTOCOLS[w]}) - 98))]} "
    done
    input_start_port ${#INSTALL_PROTOCOLS[@]}
  fi

  # 输出模式选择，输入用于订阅的 Nginx 服务端口号， 后台根据选择安装依赖
  [[ "$IS_SUB" = 'is_sub' || "$IS_ARGO" = 'is_argo' ]] && input_nginx_port

  # 输入服务器 IP,默认为检测到的服务器 IP，如果全部为空，则提示并退出脚本
  [ -z "$SERVER_IP" ] && reading "\n $(text 10) " SERVER_IP
  SERVER_IP=${SERVER_IP:-"$SERVER_IP_DEFAULT"} && WS_SERVER_IP_SHOW=$SERVER_IP
  [ -z "$SERVER_IP" ] && error " $(text 47) "

  # 根据服务 IP，使用不同的 warp 配置
  if [[ "$SERVER_IP" =~ : ]]; then
    WARP_ENDPOINT=2606:4700:d0::a29f:c101
    DOMAIN_STRATEG=prefer_ipv6
  else
    WARP_ENDPOINT=162.159.193.10
    DOMAIN_STRATEG=prefer_ipv4
  fi

  # 如选择有 c. hysteria2 时，选择是否使用端口跳跃
  [[ "${INSTALL_PROTOCOLS[@]}" =~ 'c' ]] && input_hopping_port

  # 如选择有 h. vmess + ws 或 i. vless + ws 时，先检测是否有支持的 http 端口可用，如有则要求输入域名和 cdn
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ 'h' ]]; then
    if [ "$IS_ARGO" = 'is_argo' ]; then
      [ "$ARGO_READY" != 'argo_ready' ] && input_argo_auth is_install
      local ARGO_READY=argo_ready
    else
      local DOMAIN_ERROR_TIME=5
      until [ -n "$VMESS_HOST_DOMAIN" ]; do
        (( DOMAIN_ERROR_TIME-- )) || true
        [ "$DOMAIN_ERROR_TIME" != 0 ] && TYPE=VMESS && reading "\n $(text 50) " VMESS_HOST_DOMAIN || error "\n $(text 3) \n"
      done
    fi
  fi

  if [[ "${INSTALL_PROTOCOLS[@]}" =~ 'i' ]]; then
    if [ "$IS_ARGO" = 'is_argo' ]; then
      [ "$ARGO_READY" != 'argo_ready' ] && input_argo_auth is_install
      local ARGO_READY=argo_ready
    else
      local DOMAIN_ERROR_TIME=5
      until [ -n "$VLESS_HOST_DOMAIN" ]; do
        (( DOMAIN_ERROR_TIME-- )) || true
        [ "$DOMAIN_ERROR_TIME" != 0 ] && TYPE=VLESS && reading "\n $(text 50) " VLESS_HOST_DOMAIN || error "\n $(text 3) \n"
      done
    fi
  fi

  # 选择或者输入 cdn
  [[ -z "$CDN" && -n "${VMESS_HOST_DOMAIN}${VLESS_HOST_DOMAIN}${ARGO_READY}" ]] && input_cdn

  # 输入 UUID ，错误超过 5 次将会退出
  UUID_DEFAULT=$(cat /proc/sys/kernel/random/uuid)
  [ -z "$UUID_CONFIRM" ] && reading "\n $(text 12) " UUID_CONFIRM
  local UUID_ERROR_TIME=5
  until [[ -z "$UUID_CONFIRM" || "${UUID_CONFIRM,,}" =~ ^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$ ]]; do
    (( UUID_ERROR_TIME-- )) || true
    [ "$UUID_ERROR_TIME" = 0 ] && error "\n $(text 3) \n" || reading "\n $(text 4) \n" UUID_CONFIRM
  done
  UUID_CONFIRM=${UUID_CONFIRM:-"$UUID_DEFAULT"}

  # 输入节点名，以系统的 hostname 作为默认
  if [ -z "$NODE_NAME_CONFIRM" ]; then
    if [ -x "$(type -p hostname)" ]; then
      NODE_NAME_DEFAULT="$(hostname)"
    elif [ -s /etc/hostname ]; then
      NODE_NAME_DEFAULT="$(cat /etc/hostname)"
    else
      NODE_NAME_DEFAULT="Sing-Box"
    fi
    reading "\n $(text 13) " NODE_NAME_CONFIRM
    NODE_NAME_CONFIRM="${NODE_NAME_CONFIRM:-"$NODE_NAME_DEFAULT"}"
  fi
}

check_dependencies() {
  # 如果是 Alpine，先升级 wget ，安装 systemctl-py 版
  if [ "$SYSTEM" = 'Alpine' ]; then
    local CHECK_WGET=$(wget 2>&1 | head -n 1)
    grep -qi 'busybox' <<< "$CHECK_WGET" && ${PACKAGE_INSTALL[int]} wget >/dev/null 2>&1
    local DEPS_CHECK=("bash" "rc-update" "virt-what" "python3" "iptables" "ip6tables")
    local DEPS_INSTALL=("bash" "openrc" "virt-what" "python3" "iptables" "ip6tables")
    for g in "${!DEPS_CHECK[@]}"; do
      [ ! -x "$(type -p ${DEPS_CHECK[g]})" ] && DEPS_ALPINE+=(${DEPS_INSTALL[g]})
    done
    if [ "${#DEPS_ALPINE[@]}" -ge 1 ]; then
      info "\n $(text 7) $(sed "s/ /,&/g" <<< ${DEPS_ALPINE[@]}) \n"
      ${PACKAGE_UPDATE[int]} >/dev/null 2>&1
      ${PACKAGE_INSTALL[int]} ${DEPS_ALPINE[@]} >/dev/null 2>&1
      [[ -z "$VIRT" && "${DEPS_ALPINE[@]}" =~ 'virt-what' ]] && VIRT=$(virt-what | tr '\n' ' ')
    fi

    [ ! -x "$(type -p systemctl)" ] && wget --no-check-certificate --quiet ${GH_PROXY}https://raw.githubusercontent.com/gdraheim/docker-systemctl-replacement/master/files/docker/systemctl3.py -O /bin/systemctl && chmod a+x /bin/systemctl
  fi

  # 检测 Linux 系统的依赖，升级库并重新安装依赖
  local DEPS_CHECK=("wget" "tar" "systemctl" "ss" "bash" "openssl")
  local DEPS_INSTALL=("wget" "tar" "systemctl" "iproute2" "bash" "openssl")
  for g in "${!DEPS_CHECK[@]}"; do
    [ ! -x "$(type -p ${DEPS_CHECK[g]})" ] && DEPS+=(${DEPS_INSTALL[g]})
  done

  if [ "$SYSTEM" = 'CentOS' ]; then
    if [ "$IS_CENTOS" = 'CentOS7' ]; then
      yum repolist | grep -q epef || DEPS+=(epel-release)
    fi
    [ ! -x "$(type -p firewalld)" ] && DEPS+=(firewalld)
  else
    [ ! -x "$(type -p iptables)" ] && DEPS+=(iptables)
    [ ! -x "$(type -p ip6tables)" ] && DEPS+=(ip6tables)
  fi

  # 如需要安装的依赖大于0，就更新库并安装
  if [[ "${#DEPS[@]}" > 0 ]]; then
    [[ ! "$SYSTEM" =~ Alpine|CentOS ]] && ${PACKAGE_UPDATE[int]} >/dev/null 2>&1
    ${PACKAGE_INSTALL[int]} ${DEPS[@]} >/dev/null 2>&1
    # 如新安装 firewalld，设置允许所有端口的 TCP 和 UDP 入站连接
    if [[ "${DEPS[@]}" =~ 'firewalld' ]]; then
      firewall-cmd --add-port=0-65535/tcp --permanent >/dev/null 2>&1
      firewall-cmd --add-port=0-65535/udp --permanent >/dev/null 2>&1
      firewall-cmd --reload >/dev/null 2>&1
    fi
  else
    info "\n $(text 8) \n"
  fi
}

# 检查并安装 nginx
check_nginx() {
  if [ ! -x "$(type -p nginx)" ]; then
    info "\n $(text 7) nginx \n"
    ${PACKAGE_UPDATE[int]} >/dev/null 2>&1
    ${PACKAGE_INSTALL[int]} nginx >/dev/null 2>&1
    # 如果新安装的 Nginx ，先停掉服务
    systemctl disable --now nginx >/dev/null 2>&1
  fi
}

# Json 生成两个配置文件
export_argo_json_file() {
  local FILE_PATH=$1
  [[ -z "$PORT_NGINX" && -s $WORK_DIR/nginx.conf ]] && local PORT_NGINX=$(awk '/listen/{print $2; exit}' $WORK_DIR/nginx.conf)
  [ ! -s $FILE_PATH/tunnel.json ] && echo $ARGO_JSON > $FILE_PATH/tunnel.json
  [ ! -s $FILE_PATH/tunnel.yml ] && cat > $FILE_PATH/tunnel.yml << EOF
tunnel: $(awk -F '"' '{print $12}' <<< "$ARGO_JSON")
credentials-file: $WORK_DIR/tunnel.json

ingress:
  - hostname: ${ARGO_DOMAIN}
    service: http://localhost:${PORT_NGINX}
  - service: http_status:404
EOF
}

# 生成100年的自签证书
ssl_certificate() {
  mkdir -p $WORK_DIR/cert
  openssl ecparam -genkey -name prime256v1 -out $WORK_DIR/cert/private.key && openssl req -new -x509 -days 36500 -key $WORK_DIR/cert/private.key -out $WORK_DIR/cert/cert.pem -subj "/CN=$(awk -F . '{print $(NF-1)"."$NF}' <<< "$TLS_SERVER_DEFAULT")"
}

# 处理防火墙规则
check_firewall_configuration() {
  if [[ -s /etc/selinux/config && -x "$(type -p getenforce)" && $(getenforce) = 'Enforcing' ]]; then
    hint "\n $(text 84) "
    setenforce 0
    sed -i 's/^SELINUX=.*/# &/; /SELINUX=/a\SELINUX=disabled' /etc/selinux/config
  fi
}

# Nginx 配置文件
export_nginx_conf_file() {
  # 在添加协议，需要用到 nginx 的时候，先检测是否已经安装
  if [ ! -x "$(type -p nginx)" ]; then
    info "\n $(text 7) nginx"
    ${PACKAGE_INSTALL[int]} nginx >/dev/null 2>&1
  fi

  NGINX_CONF="user  root;
worker_processes  auto;

error_log  /dev/null;
pid        /var/run/nginx.pid;

events {
    worker_connections  1024;
}

http {
"
  [ "$IS_SUB" = 'is_sub' ] && NGINX_CONF+="
  map \$http_user_agent \$path1 {
    default                    /;               # 默认路径
    ~*v2rayN                   /v2rayn;         # 匹配 V2rayN 客户端
    ~*clash                    /clash;          # 匹配 Clash 客户端
    ~*Neko                     /neko;           # 匹配 Neko 客户端
    ~*ShadowRocket             /shadowrocket;   # 匹配 ShadowRocket  客户端
    ~*SFM                      /sing-box-pc;    # 匹配 Sing-box pc 客户端
    ~*SFI|SFA                  /sing-box-phone; # 匹配 Sing-box phone 客户端
#   ~*Chrome|Firefox|Mozilla   /;               # 添加更多的分流规则
  }
  map \$http_user_agent \$path2 {
    default                    /;               # 默认路径
    ~*v2rayN                   /v2rayn;         # 匹配 V2rayN 客户端
    ~*clash                    /clash2;         # 匹配 Clash 客户端
    ~*Neko                     /neko;           # 匹配 Neko 客户端
    ~*ShadowRocket             /shadowrocket;   # 匹配 ShadowRocket  客户端
    ~*SFM|SFI|SFA              /sing-box2;      # 匹配 Sing-box pc 和 phone 客户端
#   ~*Chrome|Firefox|Mozilla   /;               # 添加更多的分流规则
  }"

  [ "$IS_SUB" = 'is_sub' ] && NGINX_CONF+="
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';
"

  NGINX_CONF+="
    access_log  /dev/null;

    sendfile        on;
    #tcp_nopush     on;

    keepalive_timeout  65;

    #gzip  on;

    #include /etc/nginx/conf.d/*.conf;

  server {
    listen $PORT_NGINX ;  # ipv4
    listen [::]:$PORT_NGINX ;  # ipv6
#    listen $PORT_NGINX ssl http2 ;  # https
    server_name localhost;

#    ssl_certificate            $WORK_DIR/cert/cert.pem;
#    ssl_certificate_key        $WORK_DIR/cert/private.key;
#    ssl_protocols              TLSv1.3;
#    ssl_session_tickets        on;
#    ssl_stapling               off;
#    ssl_stapling_verify        off;
"

  [[ -n "$PORT_VMESS_WS" && "$IS_ARGO" = 'is_argo' ]] && NGINX_CONF+="
    # 反代 sing-box vmess websocket
    location /${UUID_CONFIRM}-vmess {
      if (\$http_upgrade != "websocket") {
         return 404;
      }
      proxy_pass                          http://127.0.0.1:${PORT_VMESS_WS};
      proxy_http_version                  1.1;
      proxy_set_header Upgrade            \$http_upgrade;
      proxy_set_header Connection         "upgrade";
      proxy_set_header X-Real-IP          \$remote_addr;
      proxy_set_header X-Forwarded-For    \$proxy_add_x_forwarded_for;
      proxy_set_header Host               \$host;
      proxy_redirect                      off;
    }
"

  [[ -n "$PORT_VLESS_WS" && "$IS_ARGO" = 'is_argo' ]] && NGINX_CONF+="
    # 反代 sing-box vless websocket
    location /${UUID_CONFIRM}-vless {
      if (\$http_upgrade != "websocket") {
         return 404;
      }
      proxy_http_version                  1.1;
      proxy_pass                          https://127.0.0.1:${PORT_VLESS_WS};
      proxy_ssl_protocols                 TLSv1.3;
      proxy_set_header Upgrade            \$http_upgrade;
      proxy_set_header Connection         "upgrade";
      proxy_set_header X-Real-IP          \$remote_addr;
      proxy_set_header X-Forwarded-For    \$proxy_add_x_forwarded_for;
      proxy_set_header Host               \$host;
      proxy_redirect                      off;
    }
"

  [ "$IS_SUB" = 'is_sub' ] && NGINX_CONF+="
    # 来自 /auto2 的分流
    location ~ ^/${UUID_CONFIRM}/auto2 {
      default_type 'text/plain; charset=utf-8';
      alias ${WORK_DIR}/subscribe/\$path2;
    }

    # 来自 /auto 的分流
    location ~ ^/${UUID_CONFIRM}/auto {
      default_type 'text/plain; charset=utf-8';
      alias ${WORK_DIR}/subscribe/\$path1;
    }

    location ~ ^/${UUID_CONFIRM}/(.*) {
      autoindex on;
      proxy_set_header X-Real-IP \$proxy_protocol_addr;
      default_type 'text/plain; charset=utf-8';
      alias ${WORK_DIR}/subscribe/\$1;
    }
"

  NGINX_CONF+="  }
}"

  echo "$NGINX_CONF" > $WORK_DIR/nginx.conf
}

# 生成 sing-box 配置文件
sing-box_json() {
  local IS_CHANGE=$1
  mkdir -p $WORK_DIR/conf $WORK_DIR/logs $WORK_DIR/subscribe

  # 判断是否为新安装，不为 change 就是新安装
  if [ "$IS_CHANGE" = 'change' ]; then
    # 判断 sing-box 主程序所在路径
    DIR=$WORK_DIR
  else
    DIR=$TEMP_DIR

    # 生成 dns 配置
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

    # 生成 outbound 配置
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

    # 生成 route 配置
    cat > $WORK_DIR/conf/02_route.json << EOF
{
    "route":{
        "rule_set":[
            {
                "tag":"geosite-openai",
                "type":"remote",
                "format":"binary",
                "url":"https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-openai.srs"
            }
        ],
        "rules":[
            {
                "domain":"api.openai.com",
                "outbound":"$CHAT_GPT_OUT_V4"
            },
            {
                "rule_set":"geosite-openai",
                "outbound":"$CHAT_GPT_OUT_V6"
            }
        ]
    }
}
EOF

    # 生成缓存文件
    cat > $WORK_DIR/conf/03_experimental.json << EOF
{
    "experimental": {
        "cache_file": {
            "enabled": true,
            "path": "$WORK_DIR/cache.db"
        }
    }
}
EOF

    # 生成 dns 配置文件
    cat > $WORK_DIR/conf/04_dns.json << EOF
{
    "dns":{
        "servers":[
            {
                "address":"local"
            }
        ]
    }
}
EOF
  fi

  # 生成 Reality 公私钥，第一次安装的时候使用新生成的；添加协议的时，使用相应数组里的第一个非空值，如全空则像第一次安装那样使用新生成的
  if [[ "${#REALITY_PRIVATE[@]}" = 0 || "${#REALITY_PUBLIC[@]}" = 0 ]]; then
    REALITY_KEYPAIR=$($DIR/sing-box generate reality-keypair) && REALITY_PRIVATE=$(awk '/PrivateKey/{print $NF}' <<< "$REALITY_KEYPAIR") && REALITY_PUBLIC=$(awk '/PublicKey/{print $NF}' <<< "$REALITY_KEYPAIR")
  else
    REALITY_PRIVATE=$(awk '{print $1}' <<< "${REALITY_PRIVATE[@]}") && REALITY_PUBLIC=$(awk '{print $1}' <<< "${REALITY_PUBLIC[@]}")
  fi

  # 生成 TLS 网站
  [ "${#TLS_SERVER[@]}" -gt 0 ] && TLS_SERVER=$(awk '{print $1}' <<< "${TLS_SERVER[@]}") || TLS_SERVER=$TLS_SERVER_DEFAULT

  # 第1个协议为 b  (a为全部)，生成 XTLS + Reality 配置
  CHECK_PROTOCOLS=b
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    [ -z "$PORT_XTLS_REALITY" ] && PORT_XTLS_REALITY=$[START_PORT+$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")]
    NODE_NAME[11]=${NODE_NAME[11]:-"$NODE_NAME_CONFIRM"} && UUID[11]=${UUID[11]:-"$UUID_CONFIRM"} && TLS_SERVER[11]=${TLS_SERVER[11]:-"$TLS_SERVER"} && REALITY_PRIVATE[11]=${REALITY_PRIVATE[11]:-"$REALITY_PRIVATE"} && REALITY_PUBLIC[11]=${REALITY_PUBLIC[11]:-"$REALITY_PUBLIC"}
    cat > $WORK_DIR/conf/11_${NODE_TAG[0]}_inbounds.json << EOF
//  "public_key":"${REALITY_PUBLIC[11]}"
{
    "inbounds":[
        {
            "type":"vless",
            "sniff":true,
            "sniff_override_destination":true,
            "tag":"${NODE_NAME[11]} ${NODE_TAG[0]}",
            "listen":"::",
            "listen_port":$PORT_XTLS_REALITY,
            "users":[
                {
                    "uuid":"${UUID[11]}",
                    "flow":""
                }
            ],
            "tls":{
                "enabled":true,
                "server_name":"${TLS_SERVER[11]}",
                "reality":{
                    "enabled":true,
                    "handshake":{
                        "server":"${TLS_SERVER[11]}",
                        "server_port":443
                    },
                    "private_key":"${REALITY_PRIVATE[11]}",
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
    [ "$IS_HOPPING" = 'is_hopping' ] && add_port_hopping_nat $PORT_HOPPING_START $PORT_HOPPING_END $PORT_HYSTERIA2
    NODE_NAME[12]=${NODE_NAME[12]:-"$NODE_NAME_CONFIRM"} && UUID[12]=${UUID[12]:-"$UUID_CONFIRM"}
    cat > $WORK_DIR/conf/12_${NODE_TAG[1]}_inbounds.json << EOF
{
    "inbounds":[
        {
            "type":"hysteria2",
            "sniff":true,
            "sniff_override_destination":true,
            "tag":"${NODE_NAME[12]} ${NODE_TAG[1]}",
            "listen":"::",
            "listen_port":$PORT_HYSTERIA2,
            "users":[
                {
                    "password":"${UUID[12]}"
                }
            ],
            "ignore_client_bandwidth":false,
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
    NODE_NAME[13]=${NODE_NAME[13]:-"$NODE_NAME_CONFIRM"} && UUID[13]=${UUID[13]:-"$UUID_CONFIRM"} && TUIC_PASSWORD=${TUIC_PASSWORD:-"$UUID_CONFIRM"} && TUIC_CONGESTION_CONTROL=${TUIC_CONGESTION_CONTROL:-"bbr"}
    cat > $WORK_DIR/conf/13_${NODE_TAG[2]}_inbounds.json << EOF
{
    "inbounds":[
        {
            "type":"tuic",
            "sniff":true,
            "sniff_override_destination":true,
            "tag":"${NODE_NAME[13]} ${NODE_TAG[2]}",
            "listen":"::",
            "listen_port":$PORT_TUIC,
            "users":[
                {
                    "uuid":"${UUID[13]}",
                    "password":"$TUIC_PASSWORD"
                }
            ],
            "congestion_control": "$TUIC_CONGESTION_CONTROL",
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

  # 生成 ShadowTLS V5 配置
  CHECK_PROTOCOLS=$(asc "$CHECK_PROTOCOLS" ++)
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    [ -z "$PORT_SHADOWTLS" ] && PORT_SHADOWTLS=$[START_PORT+$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")]
    NODE_NAME[14]=${NODE_NAME[14]:-"$NODE_NAME_CONFIRM"} && UUID[14]=${UUID[14]:-"$UUID_CONFIRM"} && TLS_SERVER[14]=${TLS_SERVER[14]:-"$TLS_SERVER"} && SHADOWTLS_PASSWORD=${SHADOWTLS_PASSWORD:-"$($DIR/sing-box generate rand --base64 16)"} && SHADOWTLS_METHOD=${SHADOWTLS_METHOD:-"2022-blake3-aes-128-gcm"}

    cat > $WORK_DIR/conf/14_${NODE_TAG[3]}_inbounds.json << EOF
{
    "inbounds":[
        {
            "type":"shadowtls",
            "sniff":true,
            "sniff_override_destination":true,
            "tag":"${NODE_NAME[14]} ${NODE_TAG[3]}",
            "listen":"::",
            "listen_port":$PORT_SHADOWTLS,
            "detour":"shadowtls-in",
            "version":3,
            "users":[
                {
                    "password":"${UUID[14]}"
                }
            ],
            "handshake":{
                "server":"${TLS_SERVER[14]}",
                "server_port":443
            },
            "strict_mode":true
        },
        {
            "type":"shadowsocks",
            "tag":"shadowtls-in",
            "listen":"127.0.0.1",
            "network":"tcp",
            "method":"$SHADOWTLS_METHOD",
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
    NODE_NAME[15]=${NODE_NAME[15]:-"$NODE_NAME_CONFIRM"} && UUID[15]=${UUID[15]:-"$UUID_CONFIRM"} && SHADOWSOCKS_METHOD=${SHADOWSOCKS_METHOD:-"aes-128-gcm"}
    cat > $WORK_DIR/conf/15_${NODE_TAG[4]}_inbounds.json << EOF
{
    "inbounds":[
        {
            "type":"shadowsocks",
            "sniff":true,
            "sniff_override_destination":true,
            "tag":"${NODE_NAME[15]} ${NODE_TAG[4]}",
            "listen":"::",
            "listen_port":$PORT_SHADOWSOCKS,
            "method":"${SHADOWSOCKS_METHOD}",
            "password":"${UUID[15]}",
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
    NODE_NAME[16]=${NODE_NAME[16]:-"$NODE_NAME_CONFIRM"} && TROJAN_PASSWORD=${TROJAN_PASSWORD:-"$UUID_CONFIRM"}
    cat > $WORK_DIR/conf/16_${NODE_TAG[5]}_inbounds.json << EOF
{
    "inbounds":[
        {
            "type":"trojan",
            "sniff":true,
            "sniff_override_destination":true,
            "tag":"${NODE_NAME[16]} ${NODE_TAG[5]}",
            "listen":"::",
            "listen_port":$PORT_TROJAN,
            "users":[
                {
                    "password":"$TROJAN_PASSWORD"
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
    NODE_NAME[17]=${NODE_NAME[17]:-"$NODE_NAME_CONFIRM"} && UUID[17]=${UUID[17]:-"$UUID_CONFIRM"} && WS_SERVER_IP[17]=${WS_SERVER_IP[17]:-"$SERVER_IP"} && CDN[17]=${CDN[17]:-"$CDN"} && VMESS_WS_PATH=${VMESS_WS_PATH:-"${UUID[17]}-vmess"}
    cat > $WORK_DIR/conf/17_${NODE_TAG[6]}_inbounds.json << EOF
//  "WS_SERVER_IP_SHOW": "${WS_SERVER_IP[17]}"
//  "VMESS_HOST_DOMAIN": "${VMESS_HOST_DOMAIN}${ARGO_DOMAIN}"
//  "CDN": "${CDN[17]}"
{
    "inbounds":[
        {
            "type":"vmess",
            "sniff":true,
            "sniff_override_destination":true,
            "tag":"${NODE_NAME[17]} ${NODE_TAG[6]}",
            "listen":"::",
            "listen_port":$PORT_VMESS_WS,
            "tcp_fast_open":false,
            "proxy_protocol":false,
            "users":[
                {
                    "uuid":"${UUID[17]}",
                    "alterId":0
                }
            ],
            "transport":{
                "type":"ws",
                "path":"/$VMESS_WS_PATH",
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
    NODE_NAME[18]=${NODE_NAME[18]:-"$NODE_NAME_CONFIRM"} && UUID[18]=${UUID[18]:-"$UUID_CONFIRM"} && WS_SERVER_IP[18]=${WS_SERVER_IP[18]:-"$SERVER_IP"} && CDN[18]=${CDN[18]:-"$CDN"} && VLESS_WS_PATH=${VLESS_WS_PATH:-"${UUID[18]}-vless"}
    cat > $WORK_DIR/conf/18_${NODE_TAG[7]}_inbounds.json << EOF
//  "WS_SERVER_IP_SHOW": "${WS_SERVER_IP[18]}"
//  "CDN": "${CDN[18]}"
{
    "inbounds":[
        {
            "type":"vless",
            "sniff_override_destination":true,
            "sniff":true,
            "tag":"${NODE_NAME[18]} ${NODE_TAG[7]}",
            "listen":"::",
            "listen_port":$PORT_VLESS_WS,
            "tcp_fast_open":false,
            "proxy_protocol":false,
            "users":[
                {
                    "name":"sing-box",
                    "uuid":"${UUID[18]}"
                }
            ],
            "transport":{
                "type":"ws",
                "path":"/$VLESS_WS_PATH",
                "max_early_data":2048,
                "early_data_header_name":"Sec-WebSocket-Protocol"
            },
            "tls":{
                "enabled":true,
                "server_name":"${VLESS_HOST_DOMAIN}${ARGO_DOMAIN}",
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
    [ -z "$PORT_H2_REALITY" ] && PORT_H2_REALITY=$[START_PORT+$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")]
    NODE_NAME[19]=${NODE_NAME[19]:-"$NODE_NAME_CONFIRM"} && UUID[19]=${UUID[19]:-"$UUID_CONFIRM"} && TLS_SERVER[19]=${TLS_SERVER[19]:-"$TLS_SERVER"} && REALITY_PRIVATE[19]=${REALITY_PRIVATE[19]:-"$REALITY_PRIVATE"} && REALITY_PUBLIC[19]=${REALITY_PUBLIC[19]:-"$REALITY_PUBLIC"}
    cat > $WORK_DIR/conf/19_${NODE_TAG[8]}_inbounds.json << EOF
//  "public_key":"${REALITY_PUBLIC[19]}"
{
    "inbounds":[
        {
            "type":"vless",
            "sniff":true,
            "sniff_override_destination":true,
            "tag":"${NODE_NAME[19]} ${NODE_TAG[8]}",
            "listen":"::",
            "listen_port":$PORT_H2_REALITY,
            "users":[
                {
                    "uuid":"${UUID[19]}"
                }
            ],
            "tls":{
                "enabled":true,
                "server_name":"${TLS_SERVER[19]}",
                "reality":{
                    "enabled":true,
                    "handshake":{
                        "server":"${TLS_SERVER[19]}",
                        "server_port":443
                    },
                    "private_key":"${REALITY_PRIVATE[19]}",
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
    [ -z "$PORT_GRPC_REALITY" ] && PORT_GRPC_REALITY=$[START_PORT+$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")]
    NODE_NAME[20]=${NODE_NAME[20]:-"$NODE_NAME_CONFIRM"} && UUID[20]=${UUID[20]:-"$UUID_CONFIRM"} && TLS_SERVER[20]=${TLS_SERVER[20]:-"$TLS_SERVER"} && REALITY_PRIVATE[20]=${REALITY_PRIVATE[20]:-"$REALITY_PRIVATE"} && REALITY_PUBLIC[20]=${REALITY_PUBLIC[20]:-"$REALITY_PUBLIC"}
    cat > $WORK_DIR/conf/20_${NODE_TAG[9]}_inbounds.json << EOF
//  "public_key":"${REALITY_PUBLIC[20]}"
{
    "inbounds":[
        {
            "type":"vless",
            "sniff":true,
            "sniff_override_destination":true,
            "tag":"${NODE_NAME[20]} ${NODE_TAG[9]}",
            "listen":"::",
            "listen_port":$PORT_GRPC_REALITY,
            "users":[
                {
                    "uuid":"${UUID[20]}"
                }
            ],
            "tls":{
                "enabled":true,
                "server_name":"${TLS_SERVER[20]}",
                "reality":{
                    "enabled":true,
                    "handshake":{
                        "server":"${TLS_SERVER[20]}",
                        "server_port":443
                    },
                    "private_key":"${REALITY_PRIVATE[20]}",
                    "short_id":[
                        ""
                    ]
                }
            },
            "transport": {
                "type": "grpc",
                "service_name": "grpc"
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
}

# Sing-box 生成守护进程文件
sing-box_systemd() {
  SING_BOX_SERVICE="[Unit]
Description=sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

[Service]
User=root
Type=simple
NoNewPrivileges=yes
TimeoutStartSec=0
WorkingDirectory=$WORK_DIR
"
  [[ -n "$PORT_NGINX" && "$IS_CENTOS" != 'CentOS7' ]] && SING_BOX_SERVICE+="ExecStartPre=$(type -p nginx) -c $WORK_DIR/nginx.conf
"
  SING_BOX_SERVICE+="ExecStart=$WORK_DIR/sing-box run -C $WORK_DIR/conf/
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target"

  echo "$SING_BOX_SERVICE" > /etc/systemd/system/sing-box.service
}

# Argo 生成守护进程文件
argo_systemd() {
  cat > /etc/systemd/system/argo.service << EOF
[Unit]
Description=Cloudflare Tunnel
After=network.target

[Service]
Type=simple
NoNewPrivileges=yes
TimeoutStartSec=0
ExecStart=$ARGO_RUNS
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
}

# 获取原有各协议的参数，先清空所有的 key-value
fetch_nodes_value() {
  unset FILE NODE_NAME PORT_XTLS_REALITY UUID TLS_SERVER REALITY_PRIVATE REALITY_PUBLIC PORT_HYSTERIA2 OBFS PORT_TUIC TUIC_PASSWORD TUIC_CONGESTION_CONTROL PORT_SHADOWTLS SHADOWTLS_PASSWORD SHADOWSOCKS_METHOD PORT_SHADOWSOCKS PORT_TROJAN TROJAN_PASSWORD PORT_VMESS_WS VMESS_WS_PATH WS_SERVER_IP WS_SERVER_IP_SHOW VMESS_HOST_DOMAIN CDN PORT_VLESS_WS VLESS_WS_PATH VLESS_HOST_DOMAIN PORT_H2_REALITY PORT_GRPC_REALITY ARGO_DOMAIN

  # 获取公共数据
  ls $WORK_DIR/conf/*-ws*inbounds.json >/dev/null 2>&1 && SERVER_IP=$(awk -F '"' '/"WS_SERVER_IP_SHOW"/{print $4; exit}' $WORK_DIR/conf/*-ws*inbounds.json) || SERVER_IP=$(grep -A1 '"tag"' $WORK_DIR/list | sed -E '/-ws(-tls)*",$/{N;d}' | awk -F '"' '/"server"/{count++; if (count == 1) {print $4; exit}}')
  EXISTED_PORTS=$(awk -F ':|,' '/listen_port/{print $2}' $WORK_DIR/conf/*_inbounds.json)
  START_PORT=$(awk 'NR == 1 { min = $0 } { if ($0 < min) min = $0; count++ } END {print min}' <<< "$EXISTED_PORTS")

  # 如有 Argo，获取 Argo Tunnel
  [[ ${STATUS[1]} =~ $(text 27)|$(text 28) ]] && grep -q '\--url' /etc/systemd/system/argo.service && cmd_systemctl enable argo && sleep 2 && [ "$(systemctl is-active argo)" = 'active' ] && fetch_quicktunnel_domain

  # 获取 Nginx 端口和路径
  [[ "${IS_SUB}" = 'is_sub' || "${IS_ARGO}" = 'is_argo' ]] && local NGINX_JSON=$(cat $WORK_DIR/nginx.conf) &&
  PORT_NGINX=$(awk '/listen/{print $2; exit}' <<< "$NGINX_JSON") &&
  UUID_CONFIRM=$(awk -F '/' '/location ~ \^/{print $2; exit}' <<< "$NGINX_JSON")

  # 获取 XTLS + Reality key-value
  [ -s $WORK_DIR/conf/*_${NODE_TAG[0]}_inbounds.json ] && local JSON=$(cat $WORK_DIR/conf/*_${NODE_TAG[0]}_inbounds.json) && NODE_NAME[11]=$(sed -n "s/.*\"tag\":\"\(.*\) ${NODE_TAG[0]}.*/\1/p" <<< "$JSON") && PORT_XTLS_REALITY=$(sed -n 's/.*"listen_port":\([0-9]\+\),/\1/gp' <<< "$JSON") && UUID[11]=$(awk -F '"' '/"uuid"/{print $4}' <<< "$JSON") && TLS_SERVER[11]=$(awk -F '"' '/"server_name"/{print $4}' <<< "$JSON") && REALITY_PRIVATE[11]=$(awk -F '"' '/"private_key"/{print $4}' <<< "$JSON") && REALITY_PUBLIC[11]=$(awk -F '"' '/"public_key"/{print $4}' <<< "$JSON")

  # 获取 Hysteria2 key-value
  [ -s $WORK_DIR/conf/*_${NODE_TAG[1]}_inbounds.json ] && local JSON=$(cat $WORK_DIR/conf/*_${NODE_TAG[1]}_inbounds.json) && NODE_NAME[12]=$(sed -n "s/.*\"tag\":\"\(.*\) ${NODE_TAG[1]}.*/\1/p" <<< "$JSON") && PORT_HYSTERIA2=$(sed -n 's/.*"listen_port":\([0-9]\+\),/\1/gp' <<< "$JSON") && UUID[12]=$(awk -F '"' '/"password"/{count++; if (count == 1) {print $4; exit}}' <<< "$JSON") && check_port_hopping_nat

  # 获取 Tuic V5 key-value
  [ -s $WORK_DIR/conf/*_${NODE_TAG[2]}_inbounds.json ] && local JSON=$(cat $WORK_DIR/conf/*_${NODE_TAG[2]}_inbounds.json) && NODE_NAME[13]=$(sed -n "s/.*\"tag\":\"\(.*\) ${NODE_TAG[2]}.*/\1/p" <<< "$JSON") && PORT_TUIC=$(sed -n 's/.*"listen_port":\([0-9]\+\),/\1/gp' <<< "$JSON") && UUID[13]=$(awk -F '"' '/"uuid"/{print $4}' <<< "$JSON") && TUIC_PASSWORD=$(awk -F '"' '/"password"/{print $4}' <<< "$JSON") && TUIC_CONGESTION_CONTROL=$(awk -F '"' '/"congestion_control"/{print $4}' <<< "$JSON")

  # 获取 ShadowTLS key-value
  [ -s $WORK_DIR/conf/*_${NODE_TAG[3]}_inbounds.json ] && local JSON=$(cat $WORK_DIR/conf/*_${NODE_TAG[3]}_inbounds.json) && NODE_NAME[14]=$(sed -n "s/.*\"tag\":\"\(.*\) ${NODE_TAG[3]}.*/\1/p" <<< "$JSON") && PORT_SHADOWTLS=$(sed -n 's/.*"listen_port":\([0-9]\+\),/\1/gp' <<< "$JSON") && UUID[14]=$(awk -F '"' '/"password"/{count++; if (count == 1) {print $4; exit}}' <<< "$JSON") && SHADOWTLS_PASSWORD=$(awk -F '"' '/"password"/{count++; if (count == 2) {print $4; exit}}' <<< "$JSON") && TLS_SERVER[14]=$(awk -F '"' '/"server"/{print $4}' <<< "$JSON") && SHADOWTLS_METHOD=$(awk -F '"' '/"method"/{print $4}' <<< "$JSON")

  # 获取 Shadowsocks key-value
  [ -s $WORK_DIR/conf/*_${NODE_TAG[4]}_inbounds.json ] && local JSON=$(cat $WORK_DIR/conf/*_${NODE_TAG[4]}_inbounds.json) && NODE_NAME[15]=$(sed -n "s/.*\"tag\":\"\(.*\) ${NODE_TAG[4]}.*/\1/p" <<< "$JSON") && PORT_SHADOWSOCKS=$(sed -n 's/.*"listen_port":\([0-9]\+\),/\1/gp' <<< "$JSON") && UUID[15]=$(awk -F '"' '/"password"/{print $4}' <<< "$JSON") && SHADOWSOCKS_METHOD=$(awk -F '"' '/"method"/{print $4}' <<< "$JSON")

  # 获取 Trojan key-value
  [ -s $WORK_DIR/conf/*_${NODE_TAG[5]}_inbounds.json ] && local JSON=$(cat $WORK_DIR/conf/*_${NODE_TAG[5]}_inbounds.json) && NODE_NAME[16]=$(sed -n "s/.*\"tag\":\"\(.*\) ${NODE_TAG[5]}.*/\1/p" <<< "$JSON") && PORT_TROJAN=$(sed -n 's/.*"listen_port":\([0-9]\+\),/\1/gp' <<< "$JSON") && TROJAN_PASSWORD=$(awk -F '"' '/"password"/{print $4}' <<< "$JSON")

  # 获取 vmess + ws key-value
  [ -s $WORK_DIR/conf/*_${NODE_TAG[6]}_inbounds.json ] && local JSON=$(cat $WORK_DIR/conf/*_${NODE_TAG[6]}_inbounds.json) && NODE_NAME[17]=$(sed -n "s/.*\"tag\":\"\(.*\) ${NODE_TAG[6]}.*/\1/p" <<< "$JSON") && PORT_VMESS_WS=$(sed -n 's/.*"listen_port":\([0-9]\+\),/\1/gp' <<< "$JSON") && UUID[17]=$(awk -F '"' '/"uuid"/{print $4}' <<< "$JSON") && VMESS_WS_PATH=$(sed -n 's#.*"path":"/\(.*\)",#\1#p' <<< "$JSON") && WS_SERVER_IP[17]=$(awk  -F '"' '/"WS_SERVER_IP_SHOW"/{print $4}' <<< "$JSON") && CDN[17]=$(awk  -F '"' '/"CDN"/{print $4}' <<< "$JSON") && [[ "${STATUS[1]}" =~ $(text 27)|$(text 28) ]] && ARGO_DOMAIN=$(awk  -F '"' '/"VMESS_HOST_DOMAIN"/{print $4}' <<< "$JSON") || VMESS_HOST_DOMAIN=$(awk  -F '"' '/"VMESS_HOST_DOMAIN"/{print $4}' <<< "$JSON")

  # 获取 vless + ws + tls key-value
  [ -s $WORK_DIR/conf/*_${NODE_TAG[7]}_inbounds.json ] && local JSON=$(cat $WORK_DIR/conf/*_${NODE_TAG[7]}_inbounds.json) && NODE_NAME[18]=$(sed -n "s/.*\"tag\":\"\(.*\) ${NODE_TAG[7]}.*/\1/p" <<< "$JSON") && PORT_VLESS_WS=$(sed -n 's/.*"listen_port":\([0-9]\+\),/\1/gp' <<< "$JSON") && UUID[18]=$(awk -F '"' '/"uuid"/{print $4}' <<< "$JSON") && VLESS_WS_PATH=$(sed -n 's#.*"path":"/\(.*\)",#\1#p' <<< "$JSON") && WS_SERVER_IP[18]=$(awk  -F '"' '/"WS_SERVER_IP_SHOW"/{print $4}' <<< "$JSON") && CDN[18]=$(awk  -F '"' '/"CDN"/{print $4}' <<< "$JSON") && [[ "${STATUS[1]}" =~ $(text 27)|$(text 28) ]] && ARGO_DOMAIN=$(awk -F '"' '/"server_name"/{print $4}' <<< "$JSON") || VLESS_HOST_DOMAIN=$(awk -F '"' '/"server_name"/{print $4}' <<< "$JSON")

  # 获取 H2 + Reality key-value
  [ -s $WORK_DIR/conf/*_${NODE_TAG[8]}_inbounds.json ] && local JSON=$(cat $WORK_DIR/conf/*_${NODE_TAG[8]}_inbounds.json) && NODE_NAME[19]=$(sed -n "s/.*\"tag\":\"\(.*\) ${NODE_TAG[8]}.*/\1/p" <<< "$JSON") && PORT_H2_REALITY=$(sed -n 's/.*"listen_port":\([0-9]\+\),/\1/gp' <<< "$JSON") && UUID[19]=$(awk -F '"' '/"uuid"/{print $4}' <<< "$JSON") && TLS_SERVER[19]=$(awk -F '"' '/"server"/{print $4}' <<< "$JSON") && REALITY_PRIVATE[19]=$(awk -F '"' '/"private_key"/{print $4}' <<< "$JSON") && REALITY_PUBLIC[19]=$(awk -F '"' '/"public_key"/{print $4}' <<< "$JSON")

  # 获取 gRPC + Reality key-value
  [ -s $WORK_DIR/conf/*_${NODE_TAG[9]}_inbounds.json ] && local JSON=$(cat $WORK_DIR/conf/*_${NODE_TAG[9]}_inbounds.json) && NODE_NAME[20]=$(sed -n "s/.*\"tag\":\"\(.*\) ${NODE_TAG[9]}.*/\1/p" <<< "$JSON") && PORT_GRPC_REALITY=$(sed -n 's/.*"listen_port":\([0-9]\+\),/\1/gp' <<< "$JSON") && UUID[20]=$(awk -F '"' '/"uuid"/{print $4}' <<< "$JSON") && TLS_SERVER[20]=$(awk -F '"' '/"server"/{print $4}' <<< "$JSON") && REALITY_PRIVATE[20]=$(awk -F '"' '/"private_key"/{print $4}' <<< "$JSON") && REALITY_PUBLIC[20]=$(awk -F '"' '/"public_key"/{print $4}' <<< "$JSON")
}

# 获取 Argo 临时隧道域名
fetch_quicktunnel_domain() {
  unset CLOUDFLARED_PID METRICS_ADDRESS ARGO_DOMAIN
  local QUICKTUNNEL_ERROR_TIME=20
  until [ -n "$ARGO_DOMAIN" ]; do
    [ "$SYSTEM" = 'Alpine' ] && CLOUDFLARED_PID=$(ps -ef | awk -v WORK_DIR="$WORK_DIR" '$0 ~ WORK_DIR"/cloudflared" {print $1; exit}') || CLOUDFLARED_PID=$(ps -ef | awk -v WORK_DIR="$WORK_DIR" '$0 ~ WORK_DIR"/cloudflared" {print $2; exit}')
    [[ -z "$METRICS_ADDRESS" && "$CLOUDFLARED_PID" =~ ^[0-9]+$ ]] && METRICS_ADDRESS=$(ss -nltp | grep "pid=$CLOUDFLARED_PID" | awk '{print $4}')
    [ -n "$METRICS_ADDRESS" ] && ARGO_DOMAIN=$(wget -qO- http://$METRICS_ADDRESS/quicktunnel | awk -F '"' '{print $4}')
    [[ ! "$ARGO_DOMAIN" =~ trycloudflare\.com$ ]] && (( QUICKTUNNEL_ERROR_TIME-- )) && sleep 2 || break
    [ "$QUICKTUNNEL_ERROR_TIME" = '0' ] && error " $(text 93) "
  done

  # 把临时隧道写到 Sing-box 相应的 ws inbounds 文件
  [ -s $WORK_DIR/conf/17_${NODE_TAG[6]}_inbounds.json ] && sed -i "s/VMESS_HOST_DOMAIN.*/VMESS_HOST_DOMAIN\": \"$ARGO_DOMAIN\"/" $WORK_DIR/conf/17_${NODE_TAG[6]}_inbounds.json
  [ -s $WORK_DIR/conf/18_${NODE_TAG[7]}_inbounds.json ] && sed -i "s/\"server_name\":.*/\"server_name\": \"$ARGO_DOMAIN\",/" $WORK_DIR/conf/18_${NODE_TAG[7]}_inbounds.json
}

# 安装 sing-box 全家桶
install_sing-box() {
  sing-box_variables
  [ -n "$PORT_NGINX" ] && check_nginx
  [ ! -d /etc/systemd/system ] && mkdir -p /etc/systemd/system
  [ ! -d $WORK_DIR/logs ] && mkdir -p $WORK_DIR/logs
  ssl_certificate
  [ "$SYSTEM" = 'CentOS' ] && check_firewall_configuration
  hint "\n $(text 2) " && wait
  sing-box_json
  echo "${L^^}" > $WORK_DIR/language
  cp $TEMP_DIR/sing-box $TEMP_DIR/jq $WORK_DIR
  [ -x $TEMP_DIR/qrencode ] && cp $TEMP_DIR/qrencode $WORK_DIR

  # 生成 sing-box systemd 配置文件
  sing-box_systemd

  # 生成 Argo systemd 配置文件，并复制 cloudflared 可执行二进制文件
  cp $TEMP_DIR/cloudflared $WORK_DIR
  [ -n "$ARGO_RUNS" ] && argo_systemd

  # 如果是 Json Argo，把配置文件复制到工作目录
  [ -n "$ARGO_JSON" ] && cp $TEMP_DIR/tunnel.* $WORK_DIR

  # 生成 Nginx 配置文件
  [ -n "$PORT_NGINX" ] && export_nginx_conf_file

  # 如果 Alpine 系统，放到开机自启动
  if [ "$SYSTEM" = 'Alpine' ]; then
    cat > /etc/local.d/sing-box.start << EOF
#!/usr/bin/env bash

systemctl start sing-box
EOF
    chmod +x /etc/local.d/sing-box.start
    rc-update add local >/dev/null 2>&1
  fi

  # 等待所有后台进程完成后,再次检测状态，运行 Sing-box
  check_install
  sleep 1
  check_sing-box_status
  if [ "$IS_ARGO" = 'is_argo' ]; then
    [ "$NONINTERACTIVE_INSTALL" = 'noninteractive_install' ] && cmd_systemctl enable argo || check_argo_status
  fi
}

export_list() {
  IS_INSTALL=$1

  check_install

  #### v1.1.9 处理的 jq 和 qrencode 二进制文件代替系统依赖的问题，此处预计6月30日删除
  if [[ "${IS_SUB}" = 'is_sub' || "${IS_ARGO}" = 'is_argo' ]]; then
    [[ ! -s $WORK_DIR/jq && -s /usr/bin/jq ]] && cp /usr/bin/jq $WORK_DIR/
    if [ ! -s $WORK_DIR/qrencode ]; then
      check_arch
      wget -qO $WORK_DIR/qrencode ${GH_PROXY}https://github.com/fscarmen/client_template/raw/main/qrencode-go/qrencode-go-linux-$QRENCODE_ARCH && chmod +x $WORK_DIR/qrencode
    fi
  fi

  [ "$IS_INSTALL" != 'install' ] && fetch_nodes_value

  # IPv6 时的 IP 处理
  if [[ "$SERVER_IP" =~ : ]]; then
    SERVER_IP_1="[$SERVER_IP]"
    SERVER_IP_2="[[$SERVER_IP]]"
  else
    SERVER_IP_1="$SERVER_IP"
    SERVER_IP_2="$SERVER_IP"
  fi

  # 使用 Argo 时，获取临时隧道域名
  ls $WORK_DIR/conf/*-ws*inbounds.json >/dev/null 2>&1 && [ "$IS_ARGO" = 'is_argo' ] && [ -z "$ARGO_DOMAIN" ] && [[ "${STATUS[1]}" = "$(text 28)" || "$NONINTERACTIVE_INSTALL" = 'noninteractive_install' ]] && fetch_quicktunnel_domain

  # 如果使用 Json 或者 Token Argo，则使用加密的而且是固定的 Argo 隧道域名，否则使用 IP:PORT 的 http 服务
  [[ "$ARGO_TYPE" = 'is_token_argo' || "$ARGO_TYPE" = 'is_json_argo' ]] && SUBSCRIBE_ADDRESS="https://$ARGO_DOMAIN" || SUBSCRIBE_ADDRESS="http://${SERVER_IP_1}:${PORT_NGINX}"

  # 生成各订阅文件
  # 生成 Clash proxy providers 订阅文件
  local CLASH_SUBSCRIBE='proxies:'

  [ -n "$PORT_XTLS_REALITY" ] && local CLASH_XTLS_REALITY="- {name: \"${NODE_NAME[11]} ${NODE_TAG[0]}\", type: vless, server: ${SERVER_IP}, port: ${PORT_XTLS_REALITY}, uuid: ${UUID[11]}, network: tcp, udp: true, tls: true, servername: ${TLS_SERVER[11]}, client-fingerprint: chrome, reality-opts: {public-key: ${REALITY_PUBLIC[11]}, short-id: \"\"}, smux: { enabled: true, protocol: 'h2mux', padding: true, max-connections: '8', min-streams: '16', statistic: true, only-tcp: false } }" &&
  local CLASH_SUBSCRIBE+="
  $CLASH_XTLS_REALITY
"
  if [ -n "$PORT_HYSTERIA2" ]; then
    [[ -n "$PORT_HOPPING_START" && -n "$PORT_HOPPING_END" ]] && local CLASH_HOPPING=" ports: ${PORT_HOPPING_START}-${PORT_HOPPING_END}, HopInterval: 60,"
    local CLASH_HYSTERIA2="- {name: \"${NODE_NAME[12]} ${NODE_TAG[1]}\", type: hysteria2, server: ${SERVER_IP}, port: ${PORT_HYSTERIA2},${CLASH_HOPPING} up: \"200 Mbps\", down: \"1000 Mbps\", password: ${UUID[12]}, skip-cert-verify: true}" &&
    local CLASH_SUBSCRIBE+="
  $CLASH_HYSTERIA2
"
  fi

  [ -n "$PORT_TUIC" ] && local CLASH_TUIC="- {name: \"${NODE_NAME[13]} ${NODE_TAG[2]}\", type: tuic, server: ${SERVER_IP}, port: ${PORT_TUIC}, uuid: ${UUID[13]}, password: ${TUIC_PASSWORD}, alpn: [h3], disable-sni: true, reduce-rtt: true, request-timeout: 8000, udp-relay-mode: native, congestion-controller: $TUIC_CONGESTION_CONTROL, skip-cert-verify: true}" &&
  local CLASH_SUBSCRIBE+="
  $CLASH_TUIC
"
  [ -n "$PORT_SHADOWTLS" ] && local CLASH_SHADOWTLS="- {name: \"${NODE_NAME[14]} ${NODE_TAG[3]}\", type: ss, server: ${SERVER_IP}, port: ${PORT_SHADOWTLS}, cipher: $SHADOWTLS_METHOD, password: $SHADOWTLS_PASSWORD, plugin: shadow-tls, client-fingerprint: chrome, plugin-opts: {host: ${TLS_SERVER[14]}, password: \"${UUID[14]}\", version: 3}, smux: { enabled: true, protocol: 'h2mux', padding: true, max-connections: '8', min-streams: '16', statistic: true, only-tcp: false } }" &&
  local CLASH_SUBSCRIBE+="
  $CLASH_SHADOWTLS
"

  [ -n "$PORT_SHADOWSOCKS" ] && local CLASH_SHADOWSOCKS="- {name: \"${NODE_NAME[15]} ${NODE_TAG[4]}\", type: ss, server: ${SERVER_IP}, port: $PORT_SHADOWSOCKS, cipher: ${SHADOWSOCKS_METHOD}, password: ${UUID[15]}, smux: { enabled: true, protocol: 'h2mux', padding: true, max-connections: '8', min-streams: '16', statistic: true, only-tcp: false } }" &&
  local CLASH_SUBSCRIBE+="
  $CLASH_SHADOWSOCKS
"
  [ -n "$PORT_TROJAN" ] && local CLASH_TROJAN="- {name: \"${NODE_NAME[16]} ${NODE_TAG[5]}\", type: trojan, server: ${SERVER_IP}, port: $PORT_TROJAN, password: $TROJAN_PASSWORD, client-fingerprint: random, skip-cert-verify: true, smux: { enabled: true, protocol: 'h2mux', padding: true, max-connections: '8', min-streams: '16', statistic: true, only-tcp: false } }" &&
  local CLASH_SUBSCRIBE+="
  $CLASH_TROJAN
"
  if [ -n "$PORT_VMESS_WS" ]; then
    if [[ "${STATUS[1]}" =~ $(text 27)|$(text 28) ]] || [[ "$IS_ARGO" = 'is_argo' && "$NONINTERACTIVE_INSTALL" = 'noninteractive_install' ]]; then
      local CLASH_VMESS_WS="- {name: \"${NODE_NAME[17]} ${NODE_TAG[6]}\", type: vmess, server: ${CDN[17]}, port: 80, uuid: ${UUID[17]}, udp: true, tls: false, alterId: 0, cipher: none, skip-cert-verify: true, network: ws, ws-opts: { path: \"/$VMESS_WS_PATH\", headers: {Host: $ARGO_DOMAIN} }, smux: { enabled: true, protocol: 'h2mux', padding: true, max-connections: '8', min-streams: '16', statistic: true, only-tcp: false } }" &&
      local CLASH_SUBSCRIBE+="
  $CLASH_VMESS_WS
"
      [ "$ARGO_TYPE" = 'is_token_argo' ] && CLASH_SUBSCRIBE+="
  # $(text 94)
"
    else
      local CLASH_VMESS_WS="- {name: \"${NODE_NAME[17]} ${NODE_TAG[6]}\", type: vmess, server: ${CDN[17]}, port: 80, uuid: ${UUID[17]}, udp: true, tls: false, alterId: 0, cipher: none, skip-cert-verify: true, network: ws, ws-opts: { path: \"/$VMESS_WS_PATH\", headers: {Host: $VMESS_HOST_DOMAIN} }, smux: { enabled: true, protocol: 'h2mux', padding: true, max-connections: '8', min-streams: '16', statistic: true, only-tcp: false } }" &&
      local WS_SERVER_IP_SHOW=${WS_SERVER_IP[17]} && local TYPE_HOST_DOMAIN=$VMESS_HOST_DOMAIN && local TYPE_PORT_WS=$PORT_VMESS_WS &&
      local CLASH_SUBSCRIBE+="
  $CLASH_VMESS_WS

  # $(text 52)
"
    fi
  fi

  if [ -n "$PORT_VLESS_WS" ]; then
     if [[ "${STATUS[1]}" =~ $(text 27)|$(text 28) ]] || [[ "$IS_ARGO" = 'is_argo' && "$NONINTERACTIVE_INSTALL" = 'noninteractive_install' ]]; then
      local CLASH_VLESS_WS="- {name: \"${NODE_NAME[18]} ${NODE_TAG[7]}\", type: vless, server: ${CDN[18]}, port: 443, uuid: ${UUID[18]}, udp: true, tls: true, servername: $ARGO_DOMAIN, network: ws, skip-cert-verify: true, ws-opts: { path: \"/$VLESS_WS_PATH\", headers: {Host: $ARGO_DOMAIN}, max-early-data: 2048, early-data-header-name: Sec-WebSocket-Protocol }, smux: { enabled: true, protocol: 'h2mux', padding: true, max-connections: '8', min-streams: '16', statistic: true, only-tcp: false } }" &&
      local CLASH_SUBSCRIBE+="
  $CLASH_VLESS_WS
"
      [ "$ARGO_TYPE" = 'is_token_argo' ] && CLASH_SUBSCRIBE+="
  # $(text 94)
"
    else
      local CLASH_VLESS_WS="- {name: \"${NODE_NAME[18]} ${NODE_TAG[7]}\", type: vless, server: ${CDN[18]}, port: 443, uuid: ${UUID[18]}, udp: true, tls: true, servername: $VLESS_HOST_DOMAIN, network: ws, skip-cert-verify: true, ws-opts: { path: \"/$VLESS_WS_PATH\", headers: {Host: $VLESS_HOST_DOMAIN}, max-early-data: 2048, early-data-header-name: Sec-WebSocket-Protocol }, smux: { enabled: true, protocol: 'h2mux', padding: true, max-connections: '8', min-streams: '16', statistic: true, only-tcp: false } }" &&
      local WS_SERVER_IP_SHOW=${WS_SERVER_IP[18]} && local TYPE_HOST_DOMAIN=$VLESS_HOST_DOMAIN && local TYPE_PORT_WS=$PORT_VLESS_WS &&
      local CLASH_SUBSCRIBE+="
  $CLASH_VLESS_WS

  # $(text 52)
"
    fi
  fi

  # Clash 的 H2 传输层未实现多路复用功能，在 Clash.Meta 中更建议使用 gRPC 协议，故不输出相关配置。 https://wiki.metacubex.one/config/proxies/vless/
  [ -n "$PORT_H2_REALITY" ]

  [ -n "$PORT_GRPC_REALITY" ] && local CLASH_GRPC_REALITY="- {name: \"${NODE_NAME[20]} ${NODE_TAG[9]}\", type: vless, server: ${SERVER_IP}, port: ${PORT_GRPC_REALITY}, uuid: ${UUID[20]}, network: grpc, tls: true, udp: true, flow:, client-fingerprint: chrome, servername: ${TLS_SERVER[20]}, grpc-opts: {  grpc-service-name: \"grpc\" }, reality-opts: { public-key: ${REALITY_PUBLIC[20]}, short-id: \"\" }, smux: { enabled: true, protocol: 'h2mux', padding: true, max-connections: '8', min-streams: '16', statistic: true, only-tcp: false } }" &&
  local CLASH_SUBSCRIBE+="
  $CLASH_GRPC_REALITY
"
  echo -n "${CLASH_SUBSCRIBE}" | sed -E '/^[ ]*#|^--/d' | sed '/^$/d' > $WORK_DIR/subscribe/proxies

  # 生成 clash 订阅配置文件

  # 模板1: 使用 proxy providers
  wget --no-check-certificate -qO- --tries=3 --timeout=2 ${GH_PROXY}${SUBSCRIBE_TEMPLATE}/clash | sed "s#NODE_NAME#${NODE_NAME_CONFIRM}#g; s#PROXY_PROVIDERS_URL#$SUBSCRIBE_ADDRESS/${UUID_CONFIRM}/proxies#" > $WORK_DIR/subscribe/clash

  # 模板2: 不使用 proxy providers
  CLASH2_PORT=("$PORT_XTLS_REALITY" "$PORT_HYSTERIA2" "$PORT_TUIC" "$PORT_SHADOWTLS" "$PORT_SHADOWSOCKS" "$PORT_TROJAN" "$PORT_VMESS_WS" "$PORT_VLESS_WS" "$PORT_GRPC_REALITY")
  CLASH2_PROXY_INSERT=("$CLASH_XTLS_REALITY" "$CLASH_HYSTERIA2" "$CLASH_TUIC" "$CLASH_SHADOWTLS" "$CLASH_SHADOWSOCKS" "$CLASH_TROJAN" "$CLASH_VMESS_WS" "$CLASH_VLESS_WS" "$CLASH_GRPC_REALITY")
  CLASH2_PROXY_GROUPS_INSERT=("- ${NODE_NAME[11]} ${NODE_TAG[0]}" "- ${NODE_NAME[12]} ${NODE_TAG[1]}" "- ${NODE_NAME[13]} ${NODE_TAG[2]}" "- ${NODE_NAME[14]} ${NODE_TAG[3]}" "- ${NODE_NAME[15]} ${NODE_TAG[4]}" "- ${NODE_NAME[16]} ${NODE_TAG[5]}" "- ${NODE_NAME[17]} ${NODE_TAG[6]}" "- ${NODE_NAME[18]} ${NODE_TAG[7]}" "- ${NODE_NAME[20]} ${NODE_TAG[9]}")

  CLASH2_YAML=$(wget --no-check-certificate -qO- --tries=3 --timeout=2 ${GH_PROXY}${SUBSCRIBE_TEMPLATE}/clash2)
  for x in ${!CLASH2_PORT[@]}; do
    [[ ${CLASH2_PORT[x]} =~ [0-9]+ ]] && CLASH2_YAML=$(sed "/proxy-groups:/i\  ${CLASH2_PROXY_INSERT[x]}" <<< "$CLASH2_YAML") && CLASH2_YAML=$(sed -E "/- name: (♻️ 自动选择|📲 电报消息|💬 OpenAi|📹 油管视频|🎥 奈飞视频|📺 巴哈姆特|📺 哔哩哔哩|🌍 国外媒体|🌏 国内媒体|📢 谷歌FCM|Ⓜ️ 微软Bing|Ⓜ️ 微软云盘|Ⓜ️ 微软服务|🍎 苹果服务|🎮 游戏平台|🎶 网易音乐|🎯 全球直连)|^rules:$/i\      ${CLASH2_PROXY_GROUPS_INSERT[x]}" <<< "$CLASH2_YAML")
  done
  echo "$CLASH2_YAML" > $WORK_DIR/subscribe/clash2

  # 生成 ShadowRocket 订阅配置文件
  [ -n "$PORT_XTLS_REALITY" ] && local SHADOWROCKET_SUBSCRIBE+="
vless://$(echo -n "auto:${UUID[11]}@${SERVER_IP_2}:${PORT_XTLS_REALITY}" | base64 -w0)?remarks=${NODE_NAME[11]} ${NODE_TAG[0]}&obfs=none&tls=1&peer=${TLS_SERVER[11]}&mux=1&pbk=${REALITY_PUBLIC[11]}
"
  if [ -n "$PORT_HYSTERIA2" ]; then
    [[ -n "$PORT_HOPPING_START" && -n "$PORT_HOPPING_END" ]] && local SHADOWROCKET_HOPPING="&mport=${PORT_HYSTERIA2},${PORT_HOPPING_START}-${PORT_HOPPING_END}"
    local SHADOWROCKET_SUBSCRIBE+="
hysteria2://${UUID[12]}@${SERVER_IP_1}:${PORT_HYSTERIA2}?insecure=1&obfs=none${SHADOWROCKET_HOPPING}#${NODE_NAME[12]}%20${NODE_TAG[1]}
"
  fi

  [ -n "$PORT_TUIC" ] && local SHADOWROCKET_SUBSCRIBE+="
tuic://${TUIC_PASSWORD}:${UUID[13]}@${SERVER_IP_2}:${PORT_TUIC}?congestion_control=$TUIC_CONGESTION_CONTROL&udp_relay_mode=native&alpn=h3&allow_insecure=1#${NODE_NAME[13]}%20${NODE_TAG[2]}
"
  [ -n "$PORT_SHADOWTLS" ] && local SHADOWROCKET_SUBSCRIBE+="
ss://$(echo -n "$SHADOWTLS_METHOD:$SHADOWTLS_PASSWORD@${SERVER_IP_2}:${PORT_SHADOWTLS}" | base64 -w0)?shadow-tls=$(echo -n "{\"version\":\"3\",\"host\":\"${TLS_SERVER[14]}\",\"password\":\"${UUID[14]}\"}" | base64 -w0)#${NODE_NAME[14]}%20${NODE_TAG[3]}
"
  [ -n "$PORT_SHADOWSOCKS" ] && local SHADOWROCKET_SUBSCRIBE+="
ss://$(echo -n "${SHADOWSOCKS_METHOD}:${UUID[15]}@${SERVER_IP_2}:$PORT_SHADOWSOCKS" | base64 -w0)#${NODE_NAME[15]}%20${NODE_TAG[4]}
"
  [ -n "$PORT_TROJAN" ] && local SHADOWROCKET_SUBSCRIBE+="
trojan://$TROJAN_PASSWORD@${SERVER_IP_1}:$PORT_TROJAN?allowInsecure=1#${NODE_NAME[16]}%20${NODE_TAG[5]}
"
  if [ -n "$PORT_VMESS_WS" ]; then
     if [[ "${STATUS[1]}" =~ $(text 27)|$(text 28) ]] || [[ "$IS_ARGO" = 'is_argo' && "$NONINTERACTIVE_INSTALL" = 'noninteractive_install' ]]; then
      local SHADOWROCKET_SUBSCRIBE+="
----------------------------
vmess://$(echo -n "none:${UUID[17]}@${CDN[17]}:80" | base64 -w0)?remarks=${NODE_NAME[17]}%20${NODE_TAG[6]}&obfsParam=$ARGO_DOMAIN&path=/$VMESS_WS_PATH&obfs=websocket&alterId=0
"
      [ "$ARGO_TYPE" = 'is_token_argo' ] && SHADOWROCKET_SUBSCRIBE+="
  # $(text 94)
"
    else
      WS_SERVER_IP_SHOW=${WS_SERVER_IP[17]} && TYPE_HOST_DOMAIN=$VMESS_HOST_DOMAIN && TYPE_PORT_WS=$PORT_VMESS_WS && local SHADOWROCKET_SUBSCRIBE+="
----------------------------
vmess://$(echo -n "none:${UUID[17]}@${CDN[17]}:80" | base64 -w0)?remarks=${NODE_NAME[17]}%20${NODE_TAG[6]}&obfsParam=$VMESS_HOST_DOMAIN&path=/$VMESS_WS_PATH&obfs=websocket&alterId=0

# $(text 52)
"
    fi
  fi

  if [ -n "$PORT_VLESS_WS" ]; then
     if [[ "${STATUS[1]}" =~ $(text 27)|$(text 28) ]] || [[ "$IS_ARGO" = 'is_argo' && "$NONINTERACTIVE_INSTALL" = 'noninteractive_install' ]]; then
      local SHADOWROCKET_SUBSCRIBE+="
----------------------------
vless://$(echo -n "auto:${UUID[18]}@${CDN[18]}:443" | base64 -w0)?remarks=${NODE_NAME[18]}%20${NODE_TAG[7]}&obfsParam=$ARGO_DOMAIN&path=/$VLESS_WS_PATH?ed=2048&obfs=websocket&tls=1&peer=$ARGO_DOMAIN&allowInsecure=1
"
      [ "$ARGO_TYPE" = 'is_token_argo' ] && SHADOWROCKET_SUBSCRIBE+="
  # $(text 94)
"
    else
      WS_SERVER_IP_SHOW=${WS_SERVER_IP[18]} && TYPE_HOST_DOMAIN=$VLESS_HOST_DOMAIN && TYPE_PORT_WS=$PORT_VLESS_WS && local SHADOWROCKET_SUBSCRIBE+="
----------------------------
vless://$(echo -n "auto:${UUID[18]}@${CDN[18]}:443" | base64 -w0)?remarks=${NODE_NAME[18]} ${NODE_TAG[7]}&obfsParam=$VLESS_HOST_DOMAIN&path=/$VLESS_WS_PATH?ed=2048&obfs=websocket&tls=1&peer=$VLESS_HOST_DOMAIN&allowInsecure=1

# $(text 52)
"
    fi
  fi

  [ -n "$PORT_H2_REALITY" ] && local SHADOWROCKET_SUBSCRIBE+="
----------------------------
vless://$(echo -n auto:${UUID[19]}@${SERVER_IP_2}:${PORT_H2_REALITY} | base64 -w0)?remarks=${NODE_NAME[19]}%20${NODE_TAG[8]}&path=/&obfs=h2&tls=1&peer=${TLS_SERVER[19]}&alpn=h2&mux=1&pbk=${REALITY_PUBLIC[19]}
"
  [ -n "$PORT_GRPC_REALITY" ] && local SHADOWROCKET_SUBSCRIBE+="
vless://$(echo -n "auto:${UUID[20]}@${SERVER_IP_2}:${PORT_GRPC_REALITY}" | base64 -w0)?remarks=${NODE_NAME[20]}%20${NODE_TAG[9]}&path=grpc&obfs=grpc&tls=1&peer=${TLS_SERVER[20]}&pbk=${REALITY_PUBLIC[20]}
"
  echo -n "$SHADOWROCKET_SUBSCRIBE" | sed -E '/^[ ]*#|^--/d' | sed '/^$/d' | base64 -w0 > $WORK_DIR/subscribe/shadowrocket

  # 生成 V2rayN 订阅文件
  [ -n "$PORT_XTLS_REALITY" ] && local V2RAYN_SUBSCRIBE+="
----------------------------
vless://${UUID[11]}@${SERVER_IP_1}:${PORT_XTLS_REALITY}?encryption=none&security=reality&sni=${TLS_SERVER[11]}&fp=chrome&pbk=${REALITY_PUBLIC[11]}&type=tcp&headerType=none#${NODE_NAME[11]// /%20}%20${NODE_TAG[0]}"

  [ -n "$PORT_HYSTERIA2" ] && local V2RAYN_SUBSCRIBE+="
----------------------------
hysteria2://${UUID[12]}@${SERVER_IP_1}:${PORT_HYSTERIA2}/?alpn=h3&insecure=1#${NODE_NAME[12]// /%20}%20${NODE_TAG[1]}"

  [ -n "$PORT_TUIC" ] && local V2RAYN_SUBSCRIBE+="
----------------------------
tuic://${UUID[13]}:${TUIC_PASSWORD}@${SERVER_IP_1}:${PORT_TUIC}?alpn=h3&congestion_control=$TUIC_CONGESTION_CONTROL#${NODE_NAME[13]// /%20}%20${NODE_TAG[2]}

# $(text 70)"

  [ -n "$PORT_SHADOWTLS" ] && local V2RAYN_SUBSCRIBE+="
----------------------------
# $(text 54)

{
  \"log\":{
      \"level\":\"warn\"
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
          \"method\":\"$SHADOWTLS_METHOD\",
          \"password\":\"$SHADOWTLS_PASSWORD\",
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
          \"password\":\"${UUID[14]}\",
          \"server\":\"${SERVER_IP}\",
          \"server_port\":${PORT_SHADOWTLS},
          \"tag\": \"shadowtls-out\",
          \"tls\":{
              \"enabled\":true,
              \"server_name\":\"${TLS_SERVER[14]}\",
              \"utls\": {
                \"enabled\": true,
                \"fingerprint\": \"chrome\"
              }
          },
          \"type\":\"shadowtls\",
          \"version\":3
      }
  ]
}"
  [ -n "$PORT_SHADOWSOCKS" ] && local V2RAYN_SUBSCRIBE+="
----------------------------
ss://$(echo -n "${SHADOWSOCKS_METHOD}:${UUID[15]}@${SERVER_IP_1}:$PORT_SHADOWSOCKS" | base64 -w0)#${NODE_NAME[15]// /%20}%20${NODE_TAG[4]}"

  [ -n "$PORT_TROJAN" ] && local V2RAYN_SUBSCRIBE+="
----------------------------
trojan://$TROJAN_PASSWORD@${SERVER_IP_1}:$PORT_TROJAN?security=tls&type=tcp&headerType=none#${NODE_NAME[16]// /%20}%20${NODE_TAG[5]}

# $(text 70)"

  if [ -n "$PORT_VMESS_WS" ]; then
     if [[ "${STATUS[1]}" =~ $(text 27)|$(text 28) ]] || [[ "$IS_ARGO" = 'is_argo' && "$NONINTERACTIVE_INSTALL" = 'noninteractive_install' ]]; then
      local V2RAYN_SUBSCRIBE+="
----------------------------
vmess://$(echo -n "{ \"v\": \"2\", \"ps\": \"${NODE_NAME[17]} ${NODE_TAG[6]}\", \"add\": \"${CDN[18]}\", \"port\": \"80\", \"id\": \"${UUID[18]}\", \"aid\": \"0\", \"scy\": \"none\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"$ARGO_DOMAIN\", \"path\": \"/$VMESS_WS_PATH\", \"tls\": \"\", \"sni\": \"\", \"alpn\": \"\" }" | base64 -w0)"
      [ "$ARGO_TYPE" = 'is_token_argo' ] && V2RAYN_SUBSCRIBE+="

  # $(text 94)
"
    else
      WS_SERVER_IP_SHOW=${WS_SERVER_IP[17]} && TYPE_HOST_DOMAIN=$VMESS_HOST_DOMAIN && TYPE_PORT_WS=$PORT_VMESS_WS && local V2RAYN_SUBSCRIBE+="
----------------------------
vmess://$(echo -n "{ \"v\": \"2\", \"ps\": \"${NODE_NAME[17]} ${NODE_TAG[6]}\", \"add\": \"${CDN[18]}\", \"port\": \"80\", \"id\": \"${UUID[18]}\", \"aid\": \"0\", \"scy\": \"none\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"$VMESS_HOST_DOMAIN\", \"path\": \"/$VMESS_WS_PATH\", \"tls\": \"\", \"sni\": \"\", \"alpn\": \"\" }" | base64 -w0)

# $(text 52)"
    fi
  fi

  if [ -n "$PORT_VLESS_WS" ]; then
     if [[ "${STATUS[1]}" =~ $(text 27)|$(text 28) ]] || [[ "$IS_ARGO" = 'is_argo' && "$NONINTERACTIVE_INSTALL" = 'noninteractive_install' ]]; then
      local V2RAYN_SUBSCRIBE+="
----------------------------
vless://${UUID[18]}@${CDN[18]}:443?encryption=none&security=tls&sni=$ARGO_DOMAIN&type=ws&host=$ARGO_DOMAIN&path=%2F$VLESS_WS_PATH%3Fed%3D2048#${NODE_NAME[18]// /%20}%20${NODE_TAG[7]}"
      [ "$ARGO_TYPE" = 'is_token_argo' ] && V2RAYN_SUBSCRIBE+="

  # $(text 94)
"
    else
      WS_SERVER_IP_SHOW=${WS_SERVER_IP[18]} && TYPE_HOST_DOMAIN=$VLESS_HOST_DOMAIN && TYPE_PORT_WS=$PORT_VLESS_WS && local V2RAYN_SUBSCRIBE+="
----------------------------
vless://${UUID[18]}@${CDN[18]}:443?encryption=none&security=tls&sni=$VLESS_HOST_DOMAIN&type=ws&host=$VLESS_HOST_DOMAIN&path=%2F$VLESS_WS_PATH%3Fed%3D2048#${NODE_NAME[18]// /%20}%20${NODE_TAG[7]}

# $(text 52)"
    fi
  fi

  [ -n "$PORT_H2_REALITY" ] && local V2RAYN_SUBSCRIBE+="
----------------------------
vless://${UUID[19]}@${SERVER_IP_1}:${PORT_H2_REALITY}?encryption=none&security=reality&sni=${TLS_SERVER[19]}&fp=chrome&pbk=${REALITY_PUBLIC[19]}&type=http#${NODE_NAME[19]// /%20}%20${NODE_TAG[8]}"

  [ -n "$PORT_GRPC_REALITY" ] && local V2RAYN_SUBSCRIBE+="
----------------------------
vless://${UUID[20]}@${SERVER_IP_1}:${PORT_GRPC_REALITY}?encryption=none&security=reality&sni=${TLS_SERVER[20]}&fp=chrome&pbk=${REALITY_PUBLIC[20]}&type=grpc&serviceName=grpc&mode=gun#${NODE_NAME[20]// /%20}%20${NODE_TAG[9]}"

  echo -n "$V2RAYN_SUBSCRIBE" | sed -E '/^[ ]*#|^[ ]+|^--|^\{|^\}/d' | sed '/^$/d' | base64 -w0 > $WORK_DIR/subscribe/v2rayn

  # 生成 NekoBox 订阅文件
  [ -n "$PORT_XTLS_REALITY" ] && local NEKOBOX_SUBSCRIBE+="
----------------------------
vless://${UUID[11]}@${SERVER_IP_1}:${PORT_XTLS_REALITY}?security=reality&sni=${TLS_SERVER[11]}&fp=chrome&pbk=${REALITY_PUBLIC[11]}&type=tcp&encryption=none#${NODE_NAME[11]}%20${NODE_TAG[0]}"

  if [ -n "$PORT_HYSTERIA2" ]; then
    [[ -n "$PORT_HOPPING_START" && -n "$PORT_HOPPING_END" ]] && NEKOBOX_HOPPING="mport=${PORT_HOPPING_START}-${PORT_HOPPING_END}&"
    local NEKOBOX_SUBSCRIBE+="
----------------------------
hy2://${UUID[12]}@${SERVER_IP_1}:${PORT_HYSTERIA2}?${NEKOBOX_HOPPING}insecure=1#${NODE_NAME[12]} ${NODE_TAG[1]}"
  fi

  [ -n "$PORT_TUIC" ] && local NEKOBOX_SUBSCRIBE+="
----------------------------
tuic://${TUIC_PASSWORD}:${UUID[13]}@${SERVER_IP_1}:${PORT_TUIC}?congestion_control=$TUIC_CONGESTION_CONTROL&alpn=h3&udp_relay_mode=native&allow_insecure=1&disable_sni=1#${NODE_NAME[13]} ${NODE_TAG[2]}"

  [ -n "$PORT_SHADOWTLS" ] && local NEKOBOX_SUBSCRIBE+="
----------------------------
nekoray://custom#$(echo -n "{\"_v\":0,\"addr\":\"127.0.0.1\",\"cmd\":[\"\"],\"core\":\"internal\",\"cs\":\"{\n    \\\"password\\\": \\\"${UUID[14]}\\\",\n    \\\"server\\\": \\\"${SERVER_IP_1}\\\",\n    \\\"server_port\\\": ${PORT_SHADOWTLS},\n    \\\"tag\\\": \\\"shadowtls-out\\\",\n    \\\"tls\\\": {\n        \\\"enabled\\\": true,\n        \\\"server_name\\\": \\\"${TLS_SERVER[14]}\\\"\n    },\n    \\\"type\\\": \\\"shadowtls\\\",\n    \\\"version\\\": 3\n}\n\",\"mapping_port\":0,\"name\":\"1-tls-not-use\",\"port\":1080,\"socks_port\":0}" | base64 -w0)

nekoray://shadowsocks#$(echo -n "{\"_v\":0,\"method\":\"$SHADOWTLS_METHOD\",\"name\":\"2-ss-not-use\",\"pass\":\"$SHADOWTLS_PASSWORD\",\"port\":0,\"stream\":{\"ed_len\":0,\"insecure\":false,\"mux_s\":0,\"net\":\"tcp\"},\"uot\":0}" | base64 -w0)"

  [ -n "$PORT_SHADOWSOCKS" ] && local NEKOBOX_SUBSCRIBE+="
----------------------------
ss://$(echo -n "${SHADOWSOCKS_METHOD}:${UUID[15]}" | base64 -w0)@${SERVER_IP_1}:$PORT_SHADOWSOCKS#${NODE_NAME[15]} ${NODE_TAG[4]}"

  [ -n "$PORT_TROJAN" ] && local NEKOBOX_SUBSCRIBE+="
----------------------------
trojan://$TROJAN_PASSWORD@${SERVER_IP_1}:$PORT_TROJAN?security=tls&allowInsecure=1&fp=random&type=tcp#${NODE_NAME[16]} ${NODE_TAG[5]}"

  if [ -n "$PORT_VMESS_WS" ]; then
     if [[ "${STATUS[1]}" =~ $(text 27)|$(text 28) ]] || [[ "$IS_ARGO" = 'is_argo' && "$NONINTERACTIVE_INSTALL" = 'noninteractive_install' ]]; then
      NEKOBOX_SUBSCRIBE+="
----------------------------
vmess://$(echo -n "{\"add\":\"${CDN[17]}\",\"aid\":\"0\",\"host\":\"$ARGO_DOMAIN\",\"id\":\"${UUID[17]}\",\"net\":\"ws\",\"path\":\"/$VMESS_WS_PATH\",\"port\":\"80\",\"ps\":\"${NODE_NAME[17]} ${NODE_TAG[6]}\",\"scy\":\"none\",\"sni\":\"\",\"tls\":\"\",\"type\":\"\",\"v\":\"2\"}" | base64 -w0)"
      [ "$ARGO_TYPE" = 'is_token_argo' ] && NEKOBOX_SUBSCRIBE+="

  # $(text 94)
"
    else
      WS_SERVER_IP_SHOW=${WS_SERVER_IP[17]} && TYPE_HOST_DOMAIN=$VMESS_HOST_DOMAIN && TYPE_PORT_WS=$PORT_VMESS_WS && local NEKOBOX_SUBSCRIBE+="
----------------------------
vmess://$(echo -n "{\"add\":\"${CDN[17]}\",\"aid\":\"0\",\"host\":\"$VMESS_HOST_DOMAIN\",\"id\":\"${UUID[17]}\",\"net\":\"ws\",\"path\":\"/$VMESS_WS_PATH\",\"port\":\"80\",\"ps\":\"${NODE_NAME[17]} ${NODE_TAG[6]}\",\"scy\":\"none\",\"sni\":\"\",\"tls\":\"\",\"type\":\"\",\"v\":\"2\"}" | base64 -w0)

# $(text 52)"
    fi
  fi

  if [ -n "$PORT_VLESS_WS" ]; then
     if [[ "${STATUS[1]}" =~ $(text 27)|$(text 28) ]] || [[ "$IS_ARGO" = 'is_argo' && "$NONINTERACTIVE_INSTALL" = 'noninteractive_install' ]]; then
      local NEKOBOX_SUBSCRIBE+="
----------------------------
vless://${UUID[18]}@${CDN[18]}:443?security=tls&sni=$ARGO_DOMAIN&type=ws&path=/$VLESS_WS_PATH?ed%3D2048&host=$ARGO_DOMAIN&encryption=none#${NODE_NAME[18]}%20${NODE_TAG[7]}"
      [ "$ARGO_TYPE" = 'is_token_argo' ] && NEKOBOX_SUBSCRIBE+="

  # $(text 94)
"
    else
      WS_SERVER_IP_SHOW=${WS_SERVER_IP[18]} && TYPE_HOST_DOMAIN=$VLESS_HOST_DOMAIN && TYPE_PORT_WS=$PORT_VLESS_WS && local NEKOBOX_SUBSCRIBE+="
----------------------------
vless://${UUID[18]}@${CDN[18]}:443?security=tls&sni=$VLESS_HOST_DOMAIN&type=ws&path=/$VLESS_WS_PATH?ed%3D2048&host=$VLESS_HOST_DOMAIN&encryption=none#${NODE_NAME[18]}%20${NODE_TAG[7]}

# $(text 52)"
    fi
  fi

  [ -n "$PORT_H2_REALITY" ] && local NEKOBOX_SUBSCRIBE+="
----------------------------
vless://${UUID[19]}@${SERVER_IP_1}:${PORT_H2_REALITY}?security=reality&sni=${TLS_SERVER[19]}&alpn=h2&fp=chrome&pbk=${REALITY_PUBLIC[19]}&type=http&encryption=none#${NODE_NAME[19]}%20${NODE_TAG[8]}"

  [ -n "$PORT_GRPC_REALITY" ] && local NEKOBOX_SUBSCRIBE+="
----------------------------
vless://${UUID[20]}@${SERVER_IP_1}:${PORT_GRPC_REALITY}?security=reality&sni=${TLS_SERVER[20]}&fp=chrome&pbk=${REALITY_PUBLIC[20]}&type=grpc&serviceName=grpc&encryption=none#${NODE_NAME[20]}%20${NODE_TAG[9]}"

  echo -n "$NEKOBOX_SUBSCRIBE" | sed -E '/^[ ]*#|^--/d' | sed '/^$/d' | base64 -w0 > $WORK_DIR/subscribe/neko

  # 生成 Sing-box 订阅文件
  [ -n "$PORT_XTLS_REALITY" ] &&
  local INBOUND_REPLACE+=" { \"type\": \"vless\", \"tag\": \"${NODE_NAME[11]} ${NODE_TAG[0]}\", \"server\":\"${SERVER_IP}\", \"server_port\":${PORT_XTLS_REALITY}, \"uuid\":\"${UUID[11]}\", \"flow\":\"\", \"packet_encoding\":\"xudp\", \"tls\":{ \"enabled\":true, \"server_name\":\"${TLS_SERVER[11]}\", \"utls\":{ \"enabled\":true, \"fingerprint\":\"chrome\" }, \"reality\":{ \"enabled\":true, \"public_key\":\"${REALITY_PUBLIC[11]}\", \"short_id\":\"\" } }, \"multiplex\": { \"enabled\": true, \"protocol\": \"h2mux\", \"max_connections\": 8, \"min_streams\": 16, \"padding\": true, \"brutal\":{ \"enabled\":true, \"up_mbps\":1000, \"down_mbps\":1000 } } }," &&
  local NODE_REPLACE+="\"${NODE_NAME[11]} ${NODE_TAG[0]}\","

  [ -n "$PORT_HYSTERIA2" ] &&
  local INBOUND_REPLACE+=" { \"type\": \"hysteria2\", \"tag\": \"${NODE_NAME[12]} ${NODE_TAG[1]}\", \"server\": \"${SERVER_IP}\", \"server_port\": ${PORT_HYSTERIA2}, \"up_mbps\": 200, \"down_mbps\": 1000, \"password\": \"${UUID[12]}\", \"tls\": { \"enabled\": true, \"insecure\": true, \"server_name\": \"\", \"alpn\": [ \"h3\" ] } }," &&
  local NODE_REPLACE+="\"${NODE_NAME[12]} ${NODE_TAG[1]}\","

  [ -n "$PORT_TUIC" ] &&
  local TUIC_INBOUND=" { \"type\": \"tuic\", \"tag\": \"${NODE_NAME[13]} ${NODE_TAG[2]}\", \"server\": \"${SERVER_IP}\", \"server_port\": ${PORT_TUIC}, \"uuid\": \"${UUID[13]}\", \"password\": \"${TUIC_PASSWORD}\", \"congestion_control\": \"$TUIC_CONGESTION_CONTROL\", \"udp_relay_mode\": \"native\", \"zero_rtt_handshake\": false, \"heartbeat\": \"10s\", \"tls\": { \"enabled\": true, \"insecure\": true, \"server_name\": \"\", \"alpn\": [ \"h3\" ] } }," &&
  local INBOUND_REPLACE+="${TUIC_INBOUND}" &&
  local NODE_REPLACE+="\"${NODE_NAME[13]} ${NODE_TAG[2]}\","

  [ -n "$PORT_SHADOWTLS" ] &&
  local SHADOWTLS_INBOUND=" { \"type\": \"shadowsocks\", \"tag\": \"${NODE_NAME[14]} ${NODE_TAG[3]}\", \"method\": \"$SHADOWTLS_METHOD\", \"password\": \"$SHADOWTLS_PASSWORD\", \"detour\": \"shadowtls-out\", \"udp_over_tcp\": false, \"multiplex\": { \"enabled\": true, \"protocol\": \"h2mux\", \"max_connections\": 8, \"min_streams\": 16, \"padding\": true, \"brutal\":{ \"enabled\":true, \"up_mbps\":1000, \"down_mbps\":1000 } } }, { \"type\": \"shadowtls\", \"tag\": \"shadowtls-out\", \"server\": \"${SERVER_IP}\", \"server_port\": ${PORT_SHADOWTLS}, \"version\": 3, \"password\": \"${UUID[14]}\", \"tls\": { \"enabled\": true, \"server_name\": \"${TLS_SERVER[14]}\", \"utls\": { \"enabled\": true, \"fingerprint\": \"chrome\" } } }," &&
  local INBOUND_REPLACE+="${SHADOWTLS_INBOUND}" &&
  local NODE_REPLACE+="\"${NODE_NAME[14]} ${NODE_TAG[3]}\","

  [ -n "$PORT_SHADOWSOCKS" ] &&
  local INBOUND_REPLACE+=" { \"type\": \"shadowsocks\", \"tag\": \"${NODE_NAME[15]} ${NODE_TAG[4]}\", \"server\": \"${SERVER_IP}\", \"server_port\": $PORT_SHADOWSOCKS, \"method\": \"${SHADOWSOCKS_METHOD}\", \"password\": \"${UUID[15]}\", \"multiplex\": { \"enabled\": true, \"protocol\": \"h2mux\", \"max_connections\": 8, \"min_streams\": 16, \"padding\": true, \"brutal\":{ \"enabled\":true, \"up_mbps\":1000, \"down_mbps\":1000 } } }," &&
  local NODE_REPLACE+="\"${NODE_NAME[15]} ${NODE_TAG[4]}\","

  [ -n "$PORT_TROJAN" ] &&
  local INBOUND_REPLACE+=" { \"type\": \"trojan\", \"tag\": \"${NODE_NAME[16]} ${NODE_TAG[5]}\", \"server\": \"${SERVER_IP}\", \"server_port\": $PORT_TROJAN, \"password\": \"$TROJAN_PASSWORD\", \"tls\": { \"enabled\":true, \"insecure\": true, \"server_name\":\"\", \"utls\": { \"enabled\":true, \"fingerprint\":\"chrome\" } }, \"multiplex\": { \"enabled\":true, \"protocol\":\"h2mux\", \"max_connections\": 8, \"min_streams\": 16, \"padding\": true, \"brutal\":{ \"enabled\":true, \"up_mbps\":1000, \"down_mbps\":1000 } } }," &&
  local NODE_REPLACE+="\"${NODE_NAME[16]} ${NODE_TAG[5]}\","

  if [ -n "$PORT_VMESS_WS" ]; then
     if [[ "${STATUS[1]}" =~ $(text 27)|$(text 28) ]] || [[ "$IS_ARGO" = 'is_argo' && "$NONINTERACTIVE_INSTALL" = 'noninteractive_install' ]]; then
      local INBOUND_REPLACE+=" { \"type\": \"vmess\", \"tag\": \"${NODE_NAME[17]} ${NODE_TAG[6]}\", \"server\":\"${CDN[17]}\", \"server_port\":80, \"uuid\":\"${UUID[17]}\", \"transport\": { \"type\":\"ws\", \"path\":\"/$VMESS_WS_PATH\", \"headers\": { \"Host\": \"$ARGO_DOMAIN\" } }, \"multiplex\": { \"enabled\":true, \"protocol\":\"h2mux\", \"max_streams\":16, \"padding\": true, \"brutal\":{ \"enabled\":true, \"up_mbps\":1000, \"down_mbps\":1000 } } }," && local NODE_REPLACE+="\"${NODE_NAME[17]} ${NODE_TAG[6]}\","
      [ "$ARGO_TYPE" = 'is_token_argo' ] && [ -z "$PROMPT" ] && local PROMPT="
  # $(text 94)"
    else
      local WS_SERVER_IP_SHOW=${WS_SERVER_IP[17]} &&
      local TYPE_HOST_DOMAIN=$VMESS_HOST_DOMAIN &&
      local TYPE_PORT_WS=$PORT_VMESS_WS &&
      local PROMPT+="
      # $(text 52)" &&
      local INBOUND_REPLACE+=" { \"type\": \"vmess\", \"tag\": \"${NODE_NAME[17]} ${NODE_TAG[6]}\", \"server\":\"${CDN[17]}\", \"server_port\":80, \"uuid\":\"${UUID[17]}\", \"transport\": { \"type\":\"ws\", \"path\":\"/$VMESS_WS_PATH\", \"headers\": { \"Host\": \"$VMESS_HOST_DOMAIN\" } }, \"multiplex\": { \"enabled\":true, \"protocol\":\"h2mux\", \"max_streams\":16, \"padding\": true, \"brutal\":{ \"enabled\":true, \"up_mbps\":1000, \"down_mbps\":1000 } } },"
    fi
    local NODE_REPLACE+="\"${NODE_NAME[17]} ${NODE_TAG[6]}\","
  fi

  if [ -n "$PORT_VLESS_WS" ]; then
    if [[ "${STATUS[1]}" =~ $(text 27)|$(text 28) ]] || [[ "$IS_ARGO" = 'is_argo' && "$NONINTERACTIVE_INSTALL" = 'noninteractive_install' ]]; then
      local INBOUND_REPLACE+=" { \"type\": \"vless\", \"tag\": \"${NODE_NAME[18]} ${NODE_TAG[7]}\", \"server\":\"${CDN[18]}\", \"server_port\":443, \"uuid\":\"${UUID[18]}\", \"tls\": { \"enabled\":true, \"server_name\":\"$ARGO_DOMAIN\", \"utls\": { \"enabled\":true, \"fingerprint\":\"chrome\" } }, \"transport\": { \"type\":\"ws\", \"path\":\"/$VLESS_WS_PATH\", \"headers\": { \"Host\": \"$ARGO_DOMAIN\" }, \"max_early_data\":2048, \"early_data_header_name\":\"Sec-WebSocket-Protocol\" }, \"multiplex\": { \"enabled\":true, \"protocol\":\"h2mux\", \"max_streams\":16, \"padding\": true, \"brutal\":{ \"enabled\":true, \"up_mbps\":1000, \"down_mbps\":1000 } } },"
      [ "$ARGO_TYPE" = 'is_token_argo' ] && [ -z "$PROMPT" ] && local PROMPT="
  # $(text 94)"
    else
      local WS_SERVER_IP_SHOW=${WS_SERVER_IP[18]} &&
      local TYPE_HOST_DOMAIN=$VLESS_HOST_DOMAIN &&
      local TYPE_PORT_WS=$PORT_VLESS_WS &&
      local PROMPT+="
      # $(text 52)" &&
      local INBOUND_REPLACE+=" { \"type\": \"vless\", \"tag\": \"${NODE_NAME[18]} ${NODE_TAG[7]}\", \"server\":\"${CDN[18]}\", \"server_port\":443, \"uuid\":\"${UUID[18]}\", \"tls\": { \"enabled\":true, \"server_name\":\"$VLESS_HOST_DOMAIN\", \"utls\": { \"enabled\":true, \"fingerprint\":\"chrome\" } }, \"transport\": { \"type\":\"ws\", \"path\":\"/$VLESS_WS_PATH\", \"headers\": { \"Host\": \"$VLESS_HOST_DOMAIN\" }, \"max_early_data\":2048, \"early_data_header_name\":\"Sec-WebSocket-Protocol\" }, \"multiplex\": { \"enabled\":true, \"protocol\":\"h2mux\", \"max_streams\":16, \"padding\": true, \"brutal\":{ \"enabled\":true, \"up_mbps\":1000, \"down_mbps\":1000 } } },"
    fi
    local NODE_REPLACE+="\"${NODE_NAME[18]} ${NODE_TAG[7]}\","
  fi

  [ -n "$PORT_H2_REALITY" ] &&
  local REALITY_H2_INBOUND=" { \"type\": \"vless\", \"tag\": \"${NODE_NAME[19]} ${NODE_TAG[8]}\", \"server\": \"${SERVER_IP}\", \"server_port\": ${PORT_H2_REALITY}, \"uuid\":\"${UUID[19]}\", \"tls\": { \"enabled\":true, \"server_name\":\"${TLS_SERVER[19]}\", \"utls\": { \"enabled\":true, \"fingerprint\":\"chrome\" }, \"reality\":{ \"enabled\":true, \"public_key\":\"${REALITY_PUBLIC[19]}\", \"short_id\":\"\" } }, \"packet_encoding\": \"xudp\", \"transport\": { \"type\": \"http\" } }," &&
  local REALITY_H2_NODE="\"${NODE_NAME[19]} ${NODE_TAG[8]}\"" &&
  local NODE_REPLACE+="${REALITY_H2_NODE}," &&
  local INBOUND_REPLACE+=" ${REALITY_H2_INBOUND}"

  [ -n "$PORT_GRPC_REALITY" ] &&
  local INBOUND_REPLACE+=" { \"type\": \"vless\", \"tag\": \"${NODE_NAME[20]} ${NODE_TAG[9]}\", \"server\": \"${SERVER_IP}\", \"server_port\": ${PORT_GRPC_REALITY}, \"uuid\":\"${UUID[20]}\", \"tls\": { \"enabled\":true, \"server_name\":\"${TLS_SERVER[20]}\", \"utls\": { \"enabled\":true, \"fingerprint\":\"chrome\" }, \"reality\":{ \"enabled\":true, \"public_key\":\"${REALITY_PUBLIC[20]}\", \"short_id\":\"\" } }, \"packet_encoding\": \"xudp\", \"transport\": { \"type\": \"grpc\", \"service_name\": \"grpc\" } }," &&
  local NODE_REPLACE+="\"${NODE_NAME[20]} ${NODE_TAG[9]}\","

  # 模板1
  local SING_BOX_JSON1=$(wget --no-check-certificate -qO- --tries=3 --timeout=2 ${GH_PROXY}${SUBSCRIBE_TEMPLATE}/sing-box1)
  echo $SING_BOX_JSON1 | sed 's#, {[^}]\+"tun-in"[^}]\+}##' | sed "s#\"<INBOUND_REPLACE>\",#$INBOUND_REPLACE#; s#\"<NODE_REPLACE>\"#${NODE_REPLACE%,}#g" | $WORK_DIR/jq > $WORK_DIR/subscribe/sing-box-pc
  echo $SING_BOX_JSON1 | sed 's# {[^}]\+"mixed"[^}]\+},##; s#, "auto_detect_interface": true##' | sed "s#\"<INBOUND_REPLACE>\",#$INBOUND_REPLACE#; s#\"<NODE_REPLACE>\"#${NODE_REPLACE%,}#g" | $WORK_DIR/jq > $WORK_DIR/subscribe/sing-box-phone

  # 模板2
  local SING_BOX_JSON2=$(wget --no-check-certificate -qO- --tries=3 --timeout=2 ${GH_PROXY}${SUBSCRIBE_TEMPLATE}/sing-box2)
  echo $SING_BOX_JSON2 | sed "s#\"<INBOUND_REPLACE>\",#$INBOUND_REPLACE#; s#\"<NODE_REPLACE>\"#${NODE_REPLACE%,}#g" | $WORK_DIR/jq > $WORK_DIR/subscribe/sing-box2

  # 生成二维码 url 文件
  [ "$IS_SUB" = 'is_sub' ] && cat > $WORK_DIR/subscribe/qr << EOF
$(text 81):
$(text 82) 1:
$SUBSCRIBE_ADDRESS/${UUID_CONFIRM}/auto

$(text 82) 2:
$SUBSCRIBE_ADDRESS/${UUID_CONFIRM}/auto2

$(text 80) QRcode:
$(text 82) 1:
https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=$SUBSCRIBE_ADDRESS/${UUID_CONFIRM}/auto

$(text 82) 2:
https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=$SUBSCRIBE_ADDRESS/${UUID_CONFIRM}/auto2

$(text 82) 1:
$($WORK_DIR/qrencode "$SUBSCRIBE_ADDRESS/${UUID_CONFIRM}/auto")

$(text 82) 2:
$($WORK_DIR/qrencode "$SUBSCRIBE_ADDRESS/${UUID_CONFIRM}/auto2")
EOF

  # 生成配置文件
  EXPORT_LIST_FILE="*******************************************
┌────────────────┐
│                │
│     $(warning "V2rayN")     │
│                │
└────────────────┘
$(info "${V2RAYN_SUBSCRIBE}")

*******************************************
┌────────────────┐
│                │
│  $(warning "ShadowRocket")  │
│                │
└────────────────┘
----------------------------
$(hint "${SHADOWROCKET_SUBSCRIBE}")

*******************************************
┌────────────────┐
│                │
│   $(warning "Clash Meta")   │
│                │
└────────────────┘
----------------------------

$(info "$(sed '1d' <<< "${CLASH_SUBSCRIBE}")")

*******************************************
┌────────────────┐
│                │
│    $(warning "NekoBox")     │
│                │
└────────────────┘
$(hint "${NEKOBOX_SUBSCRIBE}")

*******************************************
┌────────────────┐
│                │
│    $(warning "Sing-box")    │
│                │
└────────────────┘
----------------------------

$(info "$(echo "{ \"outbounds\":[ ${INBOUND_REPLACE%,} ] }" | $WORK_DIR/jq)

${PROMPT}

  $(text 72)")
"

  [ "$IS_SUB" = 'is_sub' ] && EXPORT_LIST_FILE+="

*******************************************

$(hint "Index:
$SUBSCRIBE_ADDRESS/${UUID_CONFIRM}/

QR code:
$SUBSCRIBE_ADDRESS/${UUID_CONFIRM}/qr

V2rayN $(text 80):
$SUBSCRIBE_ADDRESS/${UUID_CONFIRM}/v2rayn")

$(hint "NekoBox $(text 80):
$SUBSCRIBE_ADDRESS/${UUID_CONFIRM}/neko")

$(hint "Clash $(text 80):
$SUBSCRIBE_ADDRESS/${UUID_CONFIRM}/clash
$SUBSCRIBE_ADDRESS/${UUID_CONFIRM}/clash2

sing-box for pc $(text 80):
$SUBSCRIBE_ADDRESS/${UUID_CONFIRM}/sing-box-pc

sing-box for cellphone $(text 80):
$SUBSCRIBE_ADDRESS/${UUID_CONFIRM}/sing-box-phone

SFI / SFA / SFM $(text 80):
$SUBSCRIBE_ADDRESS/${UUID_CONFIRM}/sing-box2

ShadowRocket $(text 80):
$SUBSCRIBE_ADDRESS/${UUID_CONFIRM}/shadowrocket")

*******************************************

$(info " $(text 81):
$(text 82) 1:
$SUBSCRIBE_ADDRESS/${UUID_CONFIRM}/auto

$(text 82) 2:
$SUBSCRIBE_ADDRESS/${UUID_CONFIRM}/auto2

 $(text 80) QRcode:
$(text 82) 1:
https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=$SUBSCRIBE_ADDRESS/${UUID_CONFIRM}/auto

$(text 82) 2:
https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=$SUBSCRIBE_ADDRESS/${UUID_CONFIRM}/auto2")

$(hint "$(text 82) 1:")
$($WORK_DIR/qrencode $SUBSCRIBE_ADDRESS/${UUID_CONFIRM}/auto)

$(hint "$(text 82) 2:")
$($WORK_DIR/qrencode $SUBSCRIBE_ADDRESS/${UUID_CONFIRM}/auto2)
"

  # 生成并显示节点信息
  echo "$EXPORT_LIST_FILE" > $WORK_DIR/list
  cat $WORK_DIR/list

  # 显示脚本使用情况数据
  hint "\n*******************************************\n\n $(text 55) \n"
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
  input_start_port $OLD_CONSECUTIVE_PORTS
  cmd_systemctl disable sing-box
  for ((a=0; a<$OLD_CONSECUTIVE_PORTS; a++)) do
    [ -s $WORK_DIR/conf/${CONF_FILES[a]} ] && sed -i "s/\(.*listen_port.*:\)$((OLD_START_PORT+a))/\1$((START_PORT+a))/" $WORK_DIR/conf/*
  done
  fetch_nodes_value
  [ -n "$PORT_NGINX" ] && export_nginx_conf_file
  cmd_systemctl enable sing-box
  [ -n "$ARGO_DOMAIN" ] && export_argo_json_file
  sleep 2
  export_list
  [ "$(systemctl is-active sing-box)" = 'active' ] && info " Sing-box $(text 30) $(text 37) " || error " Sing-box $(text 30) $(text 38) "
}

# 增加或删除协议
change_protocols() {
  check_install
  [ "${STATUS[0]}" = "$(text 26)" ] && error "\n Sing-box $(text 26) "

  # 查找已安装的协议，并遍历其在所有协议列表中的名称，获取协议名后存放在 EXISTED_PROTOCOLS; 没有的协议存放在 NOT_EXISTED_PROTOCOLS
  INSTALLED_PROTOCOLS_LIST=$(awk -F '"' '/"tag":/{print $4}' $WORK_DIR/conf/*_inbounds.json | grep -v 'shadowtls-in' | awk '{print $NF}')
  for f in ${!NODE_TAG[@]}; do [[ $INSTALLED_PROTOCOLS_LIST =~ "${NODE_TAG[f]}" ]] && EXISTED_PROTOCOLS+=("${PROTOCOL_LIST[f]}") || NOT_EXISTED_PROTOCOLS+=("${PROTOCOL_LIST[f]}"); done

  # 列出已安装协议
  hint "\n $(text 63) (${#EXISTED_PROTOCOLS[@]})"
  for h in "${!EXISTED_PROTOCOLS[@]}"; do
    hint " $(asc $[h+97]). ${EXISTED_PROTOCOLS[h]} "
  done

  # 从已安装的协议中选择需要删除的协议名，并存放在 REMOVE_PROTOCOLS，把保存的协议的协议存放在 KEEP_PROTOCOLS
  reading "\n $(text 64) " REMOVE_SELECT
  # 统一为小写，去掉重复选项，处理不在可选列表里的选项，把特殊符号处理
  REMOVE_SELECT=$(sed "s/[^a-$(asc $[${#EXISTED_PROTOCOLS[@]} + 96])]//g" <<< "${REMOVE_SELECT,,}" | awk 'BEGIN{RS=""; FS=""}{delete seen; output=""; for(i=1; i<=NF; i++){ if(!seen[$i]++){ output=output $i } } print output}')

  for ((j=0; j<${#REMOVE_SELECT}; j++)); do
    REMOVE_PROTOCOLS+=("${EXISTED_PROTOCOLS[$[$(asc "$(awk "NR==$[j+1] {print}" <<< "$(grep -o . <<< "$REMOVE_SELECT")")") - 97]]}")
  done

  for k in "${EXISTED_PROTOCOLS[@]}"; do
    [[ ! "${REMOVE_PROTOCOLS[@]}" =~ "$k" ]] && KEEP_PROTOCOLS+=("$k")
  done

  # 如有未安装的协议，列表显示并选择安装，把增加的协议存在放在 ADD_PROTOCOLS
  if [ "${#NOT_EXISTED_PROTOCOLS[@]}" -gt 0 ]; then
    hint "\n $(text 65) (${#NOT_EXISTED_PROTOCOLS[@]}) "
    for i in "${!NOT_EXISTED_PROTOCOLS[@]}"; do
      hint " $(asc $[i+97]). ${NOT_EXISTED_PROTOCOLS[i]} "
    done
    reading "\n $(text 66) " ADD_SELECT
    # 统一为小写，去掉重复选项，处理不在可选列表里的选项，把特殊符号处理
    ADD_SELECT=$(sed "s/[^a-$(asc $[${#NOT_EXISTED_PROTOCOLS[@]} + 96])]//g" <<< "${ADD_SELECT,,}" | awk 'BEGIN{RS=""; FS=""}{delete seen; output=""; for(i=1; i<=NF; i++){ if(!seen[$i]++){ output=output $i } } print output}')

    for ((l=0; l<${#ADD_SELECT}; l++)); do
      ADD_PROTOCOLS+=("${NOT_EXISTED_PROTOCOLS[$[$(asc "$(awk "NR==$[l+1] {print}" <<< "$(grep -o . <<< "$ADD_SELECT")")") - 97]]}")
    done
  fi

  # 重新安装 = 保留 + 新增，如数量为 0 ，则触发卸载
  REINSTALL_PROTOCOLS=("${KEEP_PROTOCOLS[@]}" "${ADD_PROTOCOLS[@]}")
  [ "${#REINSTALL_PROTOCOLS[@]}" = 0 ] && error "\n $(text 73) "

  # 显示重新安装的协议列表，并确认是否正确
  hint "\n $(text 67) (${#REINSTALL_PROTOCOLS[@]}) "
  [ "${#KEEP_PROTOCOLS[@]}" -gt 0 ] && hint "\n $(text 74) (${#KEEP_PROTOCOLS[@]}) "
  for r in "${!KEEP_PROTOCOLS[@]}"; do
    hint " $[r+1]. ${KEEP_PROTOCOLS[r]} "
  done

  [ "${#ADD_PROTOCOLS[@]}" -gt 0 ] && hint "\n $(text 75) (${#ADD_PROTOCOLS[@]}) "
  for r in "${!ADD_PROTOCOLS[@]}"; do
    hint " $[r+1]. ${ADD_PROTOCOLS[r]} "
  done

  reading "\n $(text 68) " CONFIRM
  [ "${CONFIRM,,}" = 'n' ] && exit 0

  # 把确认安装的协议遍历所有协议列表的数组，找出其下标并变为英文小写的形式
  for m in "${!REINSTALL_PROTOCOLS[@]}"; do
    for n in "${!PROTOCOL_LIST[@]}"; do
      if [ "${REINSTALL_PROTOCOLS[m]}" = "${PROTOCOL_LIST[n]}" ]; then
        INSTALL_PROTOCOLS+=($(asc $[n+98]))
      fi
    done
  done

  # 获取各节点信息
  fetch_nodes_value

  # 用于新节点的配置信息
  UUID_CONFIRM=$(awk '{print $1}' <<< "${UUID[@]} $TROJAN_PASSWORD")
  for v in "${NODE_NAME[@]}"; do
    [ -n "$v" ] && NODE_NAME_CONFIRM="$v" && break
  done
  [ "${#WS_SERVER_IP[@]}" -gt 0 ] && WS_SERVER_IP_SHOW=$(awk '{print $1}' <<< "${WS_SERVER_IP[@]}") && CDN=$(awk '{print $1}' <<< "${CDN[@]}")

  # 寻找待删除协议的 inbound 文件名
  for o in "${REMOVE_PROTOCOLS[@]}"; do
    for s in ${!PROTOCOL_LIST[@]}; do
      [ "$o" = "${PROTOCOL_LIST[s]}" ] && REMOVE_FILE+=("${NODE_TAG[s]}_inbounds.json")
    done
  done

  # 如有需要，删除 hysteria2 跳跃端口，待后面添加回来
  [ "$IS_HOPPING" = 'is_hopping' ] && del_port_hopping_nat

  # 删除不需要的协议配置文件
  [ "${#REMOVE_FILE[@]}" -gt 0 ] && for t in "${REMOVE_FILE[@]}"; do
    rm -f $WORK_DIR/conf/*${t}
  done

  # 寻找已存在协议中原有的端口号
  for p in "${KEEP_PROTOCOLS[@]}"; do
    for u in "${!PROTOCOL_LIST[@]}"; do
      [ "$p" = "${PROTOCOL_LIST[u]}" ] && KEEP_PORTS+=("$(awk -F '[:,]' '/listen_port/{print $2}' $WORK_DIR/conf/*${NODE_TAG[u]}_inbounds.json)")
    done
  done

  # 根据全部协议，找到空余的端口号
  for q in "${!REINSTALL_PROTOCOLS[@]}"; do
    [[ ! ${KEEP_PORTS[@]} =~ $[START_PORT + q] ]] && ADD_PORTS+=($[START_PORT + q])
  done

  # 所有协议的端口号
  REINSTALL_PORTS=(${KEEP_PORTS[@]} ${ADD_PORTS[@]})

  CHECK_PROTOCOLS=b
  # 获取 Reality 端口
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    POSITION=$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")
    PORT_XTLS_REALITY=${REINSTALL_PORTS[POSITION]}
  else
    unset PORT_XTLS_REALITY
  fi

  # 获取 Hysteria2 端口
  CHECK_PROTOCOLS=$(asc "$CHECK_PROTOCOLS" ++)
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    POSITION=$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")
    PORT_HYSTERIA2=${REINSTALL_PORTS[POSITION]}
    [ -z "${PORT_HOPPING_START}${PORT_HOPPING_END}" ] && input_hopping_port
  else
    unset PORT_HYSTERIA2
  fi

  # 获取 Tuic V5 端口
  CHECK_PROTOCOLS=$(asc "$CHECK_PROTOCOLS" ++)
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    POSITION=$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")
    PORT_TUIC=${REINSTALL_PORTS[POSITION]}
  else
    unset PORT_TUIC
  fi

  # 获取 ShadowTLS 端口
  CHECK_PROTOCOLS=$(asc "$CHECK_PROTOCOLS" ++)
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    POSITION=$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")
    PORT_SHADOWTLS=${REINSTALL_PORTS[POSITION]}
  fi

  # 获取 Shadowsocks 端口
  CHECK_PROTOCOLS=$(asc "$CHECK_PROTOCOLS" ++)
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    POSITION=$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")
    PORT_SHADOWSOCKS=${REINSTALL_PORTS[POSITION]}
  else
    unset PORT_SHADOWSOCKS
  fi

  # 获取 Trojan 端口
  CHECK_PROTOCOLS=$(asc "$CHECK_PROTOCOLS" ++)
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    POSITION=$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")
    PORT_TROJAN=${REINSTALL_PORTS[POSITION]}
  else
    unset PORT_TROJAN
  fi

  # 获取 ws 的 argo 或者 origin 状态
  if [ -s /etc/systemd/system/argo.service ]; then
    local ARGO_ORIGIN_RULES_STATUS=is_argo
    ARGO_RUNS=$(sed -n "s/^ExecStart=\(.*\)/\1/gp" /etc/systemd/system/argo.service)
  elif ls $WORK_DIR/conf/*-ws*inbounds.json >/dev/null 2>&1; then
    local ARGO_ORIGIN_RULES_STATUS=is_origin
  else
    local ARGO_ORIGIN_RULES_STATUS=no_argo_no_origin
  fi

  # 获取 vmess + ws 配置信息
  CHECK_PROTOCOLS=$(asc "$CHECK_PROTOCOLS" ++)
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    local DOMAIN_ERROR_TIME=5
    if [[ "$ARGO_READY" != 'argo_ready' || "$ORIGIN_READY" != 'origin_ready' ]]; then
      if [ "$ARGO_ORIGIN_RULES_STATUS" = 'is_origin' ]; then
        until [ -n "$VMESS_HOST_DOMAIN" ]; do
          (( DOMAIN_ERROR_TIME-- )) || true
          [ "$DOMAIN_ERROR_TIME" != 0 ] && TYPE=VMESS && reading "\n $(text 50) " VMESS_HOST_DOMAIN || error "\n $(text 3) \n"
        done
      elif [ "$ARGO_ORIGIN_RULES_STATUS" = 'no_argo_no_origin' ]; then
        [ -z "$ARGO_OR_ORIGIN_RULES" ] && hint "\n $(text 57) " && reading "\n $(text 24) " ARGO_OR_ORIGIN_RULES
        [ "$ARGO_OR_ORIGIN_RULES" != '2' ] && ARGO_OR_ORIGIN_RULES=1 && IS_ARGO=is_argo || IS_ARGO=no_argo
        if [ "$IS_ARGO" = 'is_argo' ]; then
          # 如果原来没有 nginx 配置，需要获取 nginx 端口信息
          [ -z "$PORT_NGINX"  ] && input_nginx_port
          until [ -n "$ARGO_RUNS" ]; do
            input_argo_auth is_add_protocols
            [ -n "$ARGO_RUNS" ] && local ARGO_READY=argo_ready && break
          done
        else
          until [ -n "$VMESS_HOST_DOMAIN" ]; do
            (( DOMAIN_ERROR_TIME-- )) || true
            [ "$DOMAIN_ERROR_TIME" != 0 ] && TYPE=VMESS && reading "\n $(text 50) " VMESS_HOST_DOMAIN || error "\n $(text 3) \n"
          done
          local ORIGIN_READY=origin_ready
        fi
      fi
    fi
    POSITION=$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")
    PORT_VMESS_WS=${REINSTALL_PORTS[POSITION]}
  else
    unset PORT_VMESS_WS
  fi

  # 获取 vless + ws + tls 配置信息
  CHECK_PROTOCOLS=$(asc "$CHECK_PROTOCOLS" ++)
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    local DOMAIN_ERROR_TIME=5
    if [[ "$ARGO_READY" != 'argo_ready' || "$ORIGIN_READY" != 'origin_ready' ]]; then
      if [ "$ARGO_ORIGIN_RULES_STATUS" = 'is_origin' ]; then
        until [ -n "$VLESS_HOST_DOMAIN" ]; do
          (( DOMAIN_ERROR_TIME-- )) || true
          [ "$DOMAIN_ERROR_TIME" != 0 ] && TYPE=VLESS && reading "\n $(text 50) " VLESS_HOST_DOMAIN || error "\n $(text   3) \n"
        done
      elif [ "$ARGO_ORIGIN_RULES_STATUS" = 'no_argo_no_origin' ]; then
        [ -z "$ARGO_OR_ORIGIN_RULES" ] && hint "\n $(text 57) " && reading "\n $(text 24) " ARGO_OR_ORIGIN_RULES
        [ "$ARGO_OR_ORIGIN_RULES" != '2' ] && ARGO_OR_ORIGIN_RULES=1 && IS_ARGO=is_argo || IS_ARGO=no_argo
        if [ "$IS_ARGO" = 'is_argo' ]; then
           # 如果原来没有 nginx 配置，需要获取 nginx 端口信息
          [ -z "$PORT_NGINX"  ] && input_nginx_port
          until [ -n "$ARGO_RUNS" ]; do
            [ "$ARGO_READY" != 'argo_ready' ] && input_argo_auth is_add_protocols
            [ -n "$ARGO_RUNS" ] && local ARGO_READY=argo_ready && break
          done
        else
          until [ -n "$VLESS_HOST_DOMAIN" ]; do
            (( DOMAIN_ERROR_TIME-- )) || true
            [ "$DOMAIN_ERROR_TIME" != 0 ] && TYPE=VLESS && reading "\n $(text 50) " VLESS_HOST_DOMAIN || error "\n $(text   3) \n"
          done
          local ORIGIN_READY=origin_ready
        fi
      fi
    fi
    POSITION=$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")
    PORT_VLESS_WS=${REINSTALL_PORTS[POSITION]}
  else
    unset PORT_VLESS_WS
  fi

  # 如之前没有 ws，现新增的 ws，则输入 cdn
  [[ "${#CDN[@]}" = '0' && ( "$ARGO_READY" = 'argo_ready' || "$ORIGIN_READY" = 'origin_ready' ) ]] && input_cdn

  # 获取 H2 + Reality 端口
  CHECK_PROTOCOLS=$(asc "$CHECK_PROTOCOLS" ++)
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    POSITION=$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")
    PORT_H2_REALITY=${REINSTALL_PORTS[POSITION]}
  else
    unset PORT_H2_REALITY
  fi

  # 获取 gRPC + Reality 端口
  CHECK_PROTOCOLS=$(asc "$CHECK_PROTOCOLS" ++)
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    POSITION=$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")
    PORT_GRPC_REALITY=${REINSTALL_PORTS[POSITION]}
  else
    unset PORT_GRPC_REALITY
  fi

  # 停止 sing-box 服务
  cmd_systemctl disable sing-box

  # 生成 Nginx 配置文件
  [ -n "$PORT_NGINX" ] && export_nginx_conf_file

  # 生成各协议的 json 文件
  sing-box_json change

  # 如有需要，安装和删除 Argo 服务
  if ls $WORK_DIR/conf/*-ws*inbounds.json >/dev/null 2>&1; then
    if [[ "$ARGO_OR_ORIGIN_RULES" != '2' && "$ARGO_ORIGIN_RULES_STATUS" != 'is_origin' && ! -s /etc/systemd/system/argo.service ]]; then
      argo_systemd
      cmd_systemctl enable argo >/dev/null 2>&1
    fi
  elif [ -s /etc/systemd/system/argo.service ]; then
    cmd_systemctl disable argo >/dev/null 2>&1
    rm -f /etc/systemd/system/argo.service
    [ -s $WORK_DIR/tunnel.json ] && rm -f $WORK_DIR/tunnel.*
  fi

  # 如有需要，删除 nginx 配置文件
  ! ls /etc/systemd/system/argo.service >/dev/null 2>&1 && [[ -s $WORK_DIR/nginx.conf && "$IS_SUB" = 'no_sub' ]] && IS_ARGO=no_argo && rm -f $WORK_DIR/nginx.conf

  # 运行 sing-box
  cmd_systemctl enable sing-box

  # 再次检测状态，运行 sing-box
  check_install

  check_sing-box_status

  export_list
}

# 卸载 sing-box 全家桶
uninstall() {
  if [ -d $WORK_DIR ]; then
    [ -s /etc/systemd/system/argo.service ] && ( cmd_systemctl disable argo 2>/dev/null; rm -f /etc/systemd/system/argo.service )
    if [ "$SYSTEM" = 'Alpine' ]; then
      cmd_systemctl disable sing-box 2>/dev/null
    else
      cmd_systemctl disable sing-box 2>/dev/null
    fi
    sleep 1
    [[ -s $WORK_DIR/nginx.conf && $(ps -ef | grep 'nginx' | wc -l) -le 1 ]] && reading "\n $(text 83) " REMOVE_NGINX
    [ "${REMOVE_NGINX,,}" = 'y' ] && ${PACKAGE_UNINSTALL[int]} nginx >/dev/null 2>&1
    [ "$IS_HOPPING" = 'is_hopping' ] && del_port_hopping_nat
    rm -rf $WORK_DIR $TEMP_DIR /etc/systemd/system/sing-box.service /usr/bin/sb
    info "\n $(text 16) \n"
  else
    error "\n $(text 15) \n"
  fi

  # 如果 Alpine 系统，删除开机自启动和python3版systemd
  if [ "$SYSTEM" = 'Alpine' ]; then
    rm -f /etc/local.d/{sing-box,argo}.start
    rc-update add local >/dev/null 2>&1
    ! ls /etc/systemd/system/*.service >/dev/null 2>&1 && rm -f /bin/systemctl
  fi
}

# Sing-box 的最新版本
version() {
  local VERSION_LATEST=$(wget --no-check-certificate -qO- ${GH_PROXY}https://api.github.com/repos/SagerNet/sing-box/releases | awk -F '["v-]' '/tag_name/{print $5}' | sort -Vr | sed -n '1p')
  local ONLINE=$(wget --no-check-certificate -qO- ${GH_PROXY}https://api.github.com/repos/SagerNet/sing-box/releases | awk -F '["v]' -v var="tag_name.*$VERSION_LATEST" '$0 ~ var {print $5; exit}')
  local LOCAL=$($WORK_DIR/sing-box version | awk '/version/{print $NF}')
  info "\n $(text 40) "
  [[ -n "$ONLINE" && "$ONLINE" != "$LOCAL" ]] && reading "\n $(text 9) " UPDATE || info " $(text 41) "

  if [ "${UPDATE,,}" = 'y' ]; then
    check_system_info
    wget --no-check-certificate --continue ${GH_PROXY}https://github.com/SagerNet/sing-box/releases/download/v$ONLINE/sing-box-$ONLINE-linux-$SING_BOX_ARCH.tar.gz -qO- | tar xz -C $TEMP_DIR sing-box-$ONLINE-linux-$SING_BOX_ARCH/sing-box

    if [ -s $TEMP_DIR/sing-box-$ONLINE-linux-$SING_BOX_ARCH/sing-box ]; then
      cmd_systemctl disable sing-box
      chmod +x $TEMP_DIR/sing-box-$ONLINE-linux-$SING_BOX_ARCH/sing-box && mv $TEMP_DIR/sing-box-$ONLINE-linux-$SING_BOX_ARCH/sing-box $WORK_DIR/sing-box
      cmd_systemctl enable sing-box && sleep 2 && [ "$(systemctl is-active sing-box)" = 'active' ] && info "\n Sing-box $(text 28) $(text 37) \n" || error "\n Sing-box $(text 28) $(text 38) \n"
    else
      error "\n $(text 42) "
    fi
  fi
}

# 判断当前 Sing-box 的运行状态，并对应的给菜单和动作赋值
menu_setting() {
  if [[ "${STATUS[0]}" =~ $(text 27)|$(text 28) ]]; then
    # 查 argo 进程号，运行时长和内存占用
    if [[ "${STATUS[1]}" =~ $(text 27)|$(text 28) ]]; then
      ARGO_VERSION=$($WORK_DIR/cloudflared -v | awk '{print $3}' | sed "s@^@Version: &@g")
      if [ "${STATUS[1]}" = "$(text 28)" ]; then
        [ "$SYSTEM" = 'Alpine' ] && ARGO_PID=$(ps -ef | awk -v WORK_DIR="$WORK_DIR" '$0 ~ WORK_DIR"/cloudflared" {print $1}') || ARGO_PID=$(ps -ef | awk -v WORK_DIR="$WORK_DIR" '$0 ~ WORK_DIR"/cloudflared" {print $2}')
        [[ "$ARGO_PID" =~ ^[0-9]+$ ]] && ARGO_MEMORY_USAGE="$(text 58): $(awk '/VmRSS/{printf "%.1f\n", $2/1024}' /proc/$ARGO_PID/status) MB"
      fi
    fi

    # 查 sing-box 进程号，运行时长和内存占用
    if [ "${STATUS[0]}" = "$(text 28)" ]; then
      [ "$SYSTEM" = 'Alpine' ] && SING_BOX_PID=$(ps -ef | awk -v WORK_DIR="$WORK_DIR" '$0 ~ WORK_DIR"/sing-box" {print $1}') || SING_BOX_PID=$(ps -ef | awk -v WORK_DIR="$WORK_DIR" '$0 ~ WORK_DIR"/sing-box" {print $2}')
      [[ "$SING_BOX_PID" =~ ^[0-9]+$ ]] && SING_BOX_MEMORY_USAGE="$(text 58): $(awk '/VmRSS/{printf "%.1f\n", $2/1024}' /proc/$SING_BOX_PID/status) MB"
    fi

    # 查 Nginx 版本号
    [ -x "$(type -p nginx)" ] && NGINX_VERSION=$(nginx -v 2>&1 | sed "s#.*/#Version: #")
    [ "$SYSTEM" = 'Alpine' ] && NGINX_PID=$(ps -ef | awk -v WORK_DIR="$WORK_DIR" '$0 ~ WORK_DIR"/nginx.conf" {print $1; exit}') || NGINX_PID=$(ps -ef | awk -v WORK_DIR="$WORK_DIR" '$0 ~ WORK_DIR"/nginx.conf" {print $2; exit}')
    [[ "$NGINX_PID" =~ ^[0-9]+$ ]] && NGINX_MEMORY_USAGE="$(text 58): $(awk '/VmRSS/{printf "%.1f\n", $2/1024}' /proc/$NGINX_PID/status) MB"

    NOW_PORTS=$(awk -F ':|,' '/listen_port/{print $2}' $WORK_DIR/conf/*)
    NOW_START_PORT=$(awk 'NR == 1 { min = $0 } { if ($0 < min) min = $0; count++ } END {print min}' <<< "$NOW_PORTS")
    NOW_CONSECUTIVE_PORTS=$(awk 'END { print NR }' <<< "$NOW_PORTS")
    [ -s $WORK_DIR/sing-box ] && SING_BOX_VERSION="Version: $($WORK_DIR/sing-box version | awk '/version/{print $NF}')"
    [ -s $WORK_DIR/conf/02_route.json ] && { grep -q 'direct' $WORK_DIR/conf/02_route.json && RETURN_STATUS=$(text 27) || RETURN_STATUS=$(text 28); }
    OPTION[1]="1 .  $(text 29)"
    [ "${STATUS[0]}" = "$(text 28)" ] && OPTION[2]="2 .  $(text 27) Sing-box (sb -s)" || OPTION[2]="2 .  $(text 28) Sing-box (sb -s)"
    [ "${STATUS[1]}" = "$(text 28)" ] && OPTION[3]="3 .  $(text 27) Argo (sb -a)" || OPTION[3]="3 .  $(text 28) Argo (sb -a)"
    OPTION[4]="4 .  $(text 92)"
    OPTION[5]="5 .  $(text 30)"
    OPTION[6]="6 .  $(text 31)"
    OPTION[7]="7 .  $(text 32)"
    OPTION[8]="8 .  $(text 62)"
    OPTION[9]="9 .  $(text 33)"
    OPTION[10]="10.  $(text 59)"
    OPTION[11]="11.  $(text 69)"
    OPTION[12]="12.  $(text 76)"

    ACTION[1]() { export_list; exit 0; }
    [ "${STATUS[0]}" = "$(text 28)" ] && ACTION[2]() { cmd_systemctl disable sing-box; [[ "$(systemctl is-active sing-box)" =~ 'inactive'|'unknown' ]] && info " Sing-box $(text 27) $(text 37)" || error " Sing-box $(text 27) $(text 38) "; } || ACTION[2]() { cmd_systemctl enable sing-box && [ "$(systemctl is-active sing-box)" = 'active' ] && info " Sing-box $(text 28) $(text 37)" || error " Sing-box $(text 28) $(text 38) "; }
    [ "${STATUS[1]}" = "$(text 28)" ] && ACTION[3]() { cmd_systemctl disable argo; [[ "$(systemctl is-active argo)" =~ 'inactive'|'unknown' ]] && info " Argo $(text 27) $(text 37)" || error " Argo $(text 27) $(text 38) "; } || ACTION[3]() { cmd_systemctl enable argo && sleep 2 && [ "$(systemctl is-active argo)" = 'active' ] && info " Argo $(text 28) $(text 37)" && ( grep -q '\--url' /etc/systemd/system/argo.service && fetch_quicktunnel_domain && export_list ) || error " Argo $(text 28) $(text 38) "; }
    ACTION[4]() { change_argo; exit; }
    ACTION[5]() { change_start_port; exit; }
    ACTION[6]() { version; exit; }
    ACTION[7]() { bash <(wget --no-check-certificate -qO- ${GH_PROXY}https://raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master/tcp.sh); exit; }
    ACTION[8]() { change_protocols; exit; }
    ACTION[9]() { uninstall; exit; }
    ACTION[10]() { bash <(wget --no-check-certificate -qO- ${GH_PROXY}https://raw.githubusercontent.com/fscarmen/argox/main/argox.sh) -$L; exit; }
    ACTION[11]() { bash <(wget --no-check-certificate -qO- ${GH_PROXY}https://raw.githubusercontent.com/fscarmen/sba/main/sba.sh) -$L; exit; }
    ACTION[12]() { bash <(wget --no-check-certificate -qO- https://tcp.hy2.sh/); exit; }
  else
    OPTION[1]="1.  $(text 34) + Argo + $(text 80) $(text 89)"
    OPTION[2]="2.  $(text 34) + Argo $(text 89)"
    OPTION[3]="3.  $(text 34) + $(text 80) $(text 89)"
    OPTION[4]="4.  $(text 34)"
    OPTION[5]="5.  $(text 32)"
    OPTION[6]="6.  $(text 59)"
    OPTION[7]="7.  $(text 69)"
    OPTION[8]="8.  $(text 76)"

    ACTION[1]() { IS_SUB=is_sub; IS_ARGO=is_argo; install_sing-box; export_list install; create_shortcut; exit; }
    ACTION[2]() { IS_SUB=no_sub; IS_ARGO=is_argo; install_sing-box; export_list install; create_shortcut; exit; }
    ACTION[3]() { IS_SUB=is_sub; IS_ARGO=no_argo; install_sing-box; export_list install; create_shortcut; exit; }
    ACTION[4]() { install_sing-box; export_list install; create_shortcut; exit; }
    ACTION[5]() { bash <(wget --no-check-certificate -qO- ${GH_PROXY}https://raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master/tcp.sh); exit; }
    ACTION[6]() { bash <(wget --no-check-certificate -qO- ${GH_PROXY}https://raw.githubusercontent.com/fscarmen/argox/main/argox.sh) -$L; exit; }
    ACTION[7]() { bash <(wget --no-check-certificate -qO- ${GH_PROXY}https://raw.githubusercontent.com/fscarmen/sba/main/sba.sh) -$L; exit; }
    ACTION[8]() { bash <(wget --no-check-certificate -qO- ${GH_PROXY}https://tcp.hy2.sh/); exit; }
  fi

  [ "${#OPTION[@]}" -ge '10' ] && OPTION[0]="0 .  $(text 35)" || OPTION[0]="0.  $(text 35)"
  ACTION[0]() { exit; }
}

menu() {
  clear
  echo -e "======================================================================================================================\n"
  info " $(text 17): $VERSION\n $(text 18): $(text 1)\n $(text 19):\n\t $(text 20): $SYS\n\t $(text 21): $(uname -r)\n\t $(text 22): $SING_BOX_ARCH\n\t $(text 23): $VIRT "
  info "\t IPv4: $WAN4 $WARPSTATUS4 $COUNTRY4  $ASNORG4 "
  info "\t IPv6: $WAN6 $WARPSTATUS6 $COUNTRY6  $ASNORG6 "
  info "\t Sing-box: ${STATUS[0]}\t $SING_BOX_VERSION\t\t $SING_BOX_MEMORY_USAGE\n\t Argo: ${STATUS[1]}\t $ARGO_VERSION\t\t $ARGO_MEMORY_USAGE\n \t Nginx: ${STATUS[0]}\t $NGINX_VERSION\t $NGINX_MEMORY_USAGE "
  echo -e "\n======================================================================================================================\n"
  for ((b=1;b<=${#OPTION[*]};b++)); do [ "$b" = "${#OPTION[*]}" ] && hint " ${OPTION[0]} " || hint " ${OPTION[b]} "; done
  reading "\n $(text 24) " CHOOSE

  # 输入必须是数字且少于等于最大可选项
  if grep -qE "^[0-9]{1,2}$" <<< "$CHOOSE" && [ "$CHOOSE" -lt "${#OPTION[*]}" ]; then
    ACTION[$CHOOSE]
  else
    warning " $(text 36) [0-$((${#OPTION[*]}-1))] " && sleep 1 && menu
  fi
}

check_cdn
statistics_of_run-times

# 传参
[[ "${*^^}" =~ '-E' ]] && L=E
[[ "${*^^}" =~ '-C'|'-B' ]] && L=C

select_language
check_system_info

# 可以是 Key Value 或者 Key=Value 的形式。传参时，
# 传参处理1: 把所有的 = 变为空格，但保留 =" ，因为 Json TunnelSecret 是 =" 结尾的，如 {"AccountTag":"9cc9e3e4d8f29d2a02e297f14f20513a","TunnelSecret":"6AYfKBOoNlPiTAuWg64ZwujsNuERpWLm6pPJ2qpN8PM=","TunnelID":"1ac55430-f4dc-47d5-a850-bdce824c4101"}
# 传参处理2: 去掉 sudo cloudflared service install ，以方便用户输入 Token 并能正确读取真正的以 ey 开头的 Value
ALL_PARAMETER=($(sed -E 's/(-c|-e|-C|-E) //; s/=([^"])/ \1/g; s/sudo cloudflared service install //' <<< $*))
[[ "${#ALL_PARAMETER[@]}" > 13 && "${ALL_PARAMETER[@]^^}" == *"--LANGUAGE"* && "${ALL_PARAMETER[@]^^}" == *"--CHOOSE_PROTOCOLS"* && "${ALL_PARAMETER[@]^^}" == *"--START_PORT"* && "${ALL_PARAMETER[@]^^}" == *"--PORT_NGINX"* && "${ALL_PARAMETER[@]^^}" == *"--SERVER_IP"* && "${ALL_PARAMETER[@]^^}" == *"--UUID"* && "${ALL_PARAMETER[@]^^}" == *"--NODE_NAME"* ]] && NONINTERACTIVE_INSTALL=noninteractive_install

# 传参处理，无交互快速安装参数
for z in ${!ALL_PARAMETER[@]}; do
  case "${ALL_PARAMETER[z]^^}" in
    -P )
      ((z++)); START_PORT=${ALL_PARAMETER[z]}; check_install; [ "${STATUS[0]}" = "$(text 26)" ] && error "\n Sing-box $(text 26) "; change_start_port; exit 0
      ;;
    -S )
      check_install; [ "${STATUS[0]}" = "$(text 26)" ] && error "\n Sing-box $(text 26) "; [ "${STATUS[0]}" = "$(text 28)" ] && ( cmd_systemctl disable sing-box; [[ "$(systemctl is-active sing-box)" =~ 'inactive'|'unknown' ]] && info "\n Sing-box $(text 27) $(text 37)" ) || ( cmd_systemctl enable sing-box && [ "$(systemctl is-active sing-box)" = 'active' ] && info "\n Sing-box $(text 28) $(text 37)" ); exit 0
      ;;
    -A )
      check_install; [ "${STATUS[1]}" = "$(text 26)" ] && error "\n Argo $(text 26) "; [ "${STATUS[1]}" = "$(text 28)" ] && ( cmd_systemctl disable argo; [[ "$(systemctl is-active argo)" =~ 'inactive'|'unknown' ]] && info "\n Argo $(text 27) $(text 37)" ) || ( cmd_systemctl enable argo && sleep 2 && [ "$(systemctl is-active argo)" = 'active' ] && info "\n Argo $(text 28) $(text 37)" && ( grep -q '\--url' /etc/systemd/system/argo.service && fetch_quicktunnel_domain && export_list ) ); exit 0
      ;;
    -T )
      change_argo; exit 0
      ;;
    -U )
      check_install; uninstall; exit 0
      ;;
    -N )
      [ ! -s $WORK_DIR/list ] && error " Sing-box $(text 26) "; export_list; exit 0
      ;;
    -V )
      check_arch; version; exit 0
      ;;
    -B )
      bash <(wget --no-check-certificate -qO- ${GH_PROXY}https://raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master/tcp.sh); exit
      ;;
    -R )
      change_protocols; exit 0
      ;;
    -F )
      ((z++)); VARIABLE_FILE=${ALL_PARAMETER[z]}; . $VARIABLE_FILE; NONINTERACTIVE_INSTALL=noninteractive_install
      ;;
    --LANGUAGE )
      ((z++)); [[ "${ALL_PARAMETER[z]^^}" =~ ^C ]] && L=C || L=E
      ;;
    --CHOOSE_PROTOCOLS )
      ((z++)); CHOOSE_PROTOCOLS=${ALL_PARAMETER[z]}
      ;;
    --START_PORT )
      ((z++)); START_PORT=${ALL_PARAMETER[z]}
      ;;
    --PORT_NGINX )
      ((z++)); PORT_NGINX=${ALL_PARAMETER[z]}
      ;;
    --SERVER_IP )
      ((z++)); SERVER_IP=${ALL_PARAMETER[z]}
      ;;
    --VMESS_HOST_DOMAIN )
      ((z++)); VMESS_HOST_DOMAIN=${ALL_PARAMETER[z]}
      ;;
    --VLESS_HOST_DOMAIN )
      ((z++)); VLESS_HOST_DOMAIN=${ALL_PARAMETER[z]}
      ;;
    --CDN )
      ((z++)); CDN=${ALL_PARAMETER[z]}
      ;;
    --UUID_CONFIRM )
      ((z++)); UUID_CONFIRM=${ALL_PARAMETER[z]}
      ;;
    --NODE_NAME_CONFIRM )
      ((z++))
      for ((z=$z; z<${#ALL_PARAMETER[@]}; z++)); do
        [[ ! "${ALL_PARAMETER[z]}" =~ ^- ]] && NODE_NAME_ARRAY+=(${ALL_PARAMETER[z]}) || break
      done
      NODE_NAME_CONFIRM=${NODE_NAME_ARRAY[@]}
      ;;
    --SUBSCRIBE )
      ((z++)); [ "${ALL_PARAMETER[z]}" = 'true' ] && IS_SUB=is_sub
      ;;
    --ARGO )
      ((z++)); [ "${ALL_PARAMETER[z]}" = 'true' ] && IS_ARGO=is_argo
      ;;
    --ARGO_DOMAIN )
      ((z++)); ARGO_DOMAIN=${ALL_PARAMETER[z]}
      ;;
    --ARGO_AUTH )
      ((z++)); ARGO_AUTH=${ALL_PARAMETER[z]}
      ;;
    --PORT_HOPPING_RANGE )
      ((z++)); [[ "${ALL_PARAMETER[z]//:/-}" =~ ^[1-6][0-9]{4}-[1-6][0-9]{4}$ ]] && PORT_HOPPING_RANGE=${ALL_PARAMETER[z]//-/:} && PORT_HOPPING_START=${ALL_PARAMETER[z]%:*} && PORT_HOPPING_END=${ALL_PARAMETER[z]#*:}
      [[ "$PORT_HOPPING_START" < "$PORT_HOPPING_END" && "$PORT_HOPPING_START" -ge "$MIN_HOPPING_PORT" && "$PORT_HOPPING_END" -le "$MAX_HOPPING_PORT" ]] && IS_HOPPING=is_hopping
      ;;
  esac
done

check_root
check_arch
check_system_info
check_dependencies
check_system_ip
check_install
if [ "$NONINTERACTIVE_INSTALL" = 'noninteractive_install' ]; then
  # 预设默认值
  IS_SUB=${IS_SUB:-'no_sub'}
  IS_ARGO=${IS_ARGO:-'no_argo'}
  IS_HOPPING=${IS_HOPPING:-'no_hoppinng'}

  install_sing-box
  export_list install
  create_shortcut
else
  menu_setting
  menu
fi
