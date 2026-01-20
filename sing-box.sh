#!/usr/bin/env bash

# 当前脚本版本号
VERSION='v1.3.3 (2026.01.20)'

# Github 反代加速代理，第一个为空相当于直连
GITHUB_PROXY=('' 'https://v6.gh-proxy.org/' 'https://gh-proxy.com/' 'https://hub.glowp.xyz/' 'https://proxy.vvvv.ee/' 'https://ghproxy.lvedong.eu.org/')

# 各变量默认值
TEMP_DIR='/tmp/sing-box'
WORK_DIR='/etc/sing-box'
START_PORT_DEFAULT='8881'
MIN_PORT=100
MAX_PORT=65520
MIN_HOPPING_PORT=10000
MAX_HOPPING_PORT=65535
TLS_SERVER_DEFAULT=addons.mozilla.org
PROTOCOL_LIST=("XTLS + reality" "hysteria2" "tuic" "ShadowTLS" "shadowsocks" "trojan" "vmess + ws" "vless + ws + tls" "H2 + reality" "gRPC + reality" "AnyTLS")
NODE_TAG=("xtls-reality" "hysteria2" "tuic" "ShadowTLS" "shadowsocks" "trojan" "vmess-ws" "vless-ws-tls" "h2-reality" "grpc-reality" "anytls")
CONSECUTIVE_PORTS=${#PROTOCOL_LIST[@]}
CDN_DOMAIN=("skk.moe" "ip.sb" "time.is" "cfip.xxxxxxxx.tk" "bestcf.top" "cdn.2020111.xyz" "xn--b6gac.eu.org" "cf.090227.xyz")
SUBSCRIBE_TEMPLATE="https://raw.githubusercontent.com/fscarmen/client_template/main"
DEFAULT_NEWEST_VERSION='1.13.0-beta.7'

export DEBIAN_FRONTEND=noninteractive

trap "rm -rf $TEMP_DIR >/dev/null 2>&1 ; echo -e '\n' ;exit" INT QUIT TERM EXIT

mkdir -p $TEMP_DIR

E[0]="Language:\n 1. English (default) \n 2. 简体中文"
C[0]="${E[0]}"
E[1]="1. Security: Add pinnedPeerCertSha256 for Hysteria2/Trojan in v2rayN to prevent MITM (replaces AllowInsecure); 2. Compatibility: Refactor SFM/SFI/SFA configs for sing-box v1.13.0+."
C[1]="1. 安全增强：v2rayN 的 Hysteria2/Trojan 支持 pinnedPeerCertSha256 替代 跳过证书验证，防御 MITM 攻击; 2. 适配更新：重构 SFM/SFI/SFA 配置，支持 sing-box v1.13.0+"
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
E[10]="Please enter VPS IP \(Default is: \${SERVER_IP_DEFAULT}\):"
C[10]="请输入 VPS IP \(默认为: \${SERVER_IP_DEFAULT}\):"
E[11]="Please enter the starting port number. Must be \${MIN_PORT} - \${MAX_PORT}, consecutive \${NUM} free ports are required \(Default is: \${START_PORT_DEFAULT}\):"
C[11]="请输入开始的端口号，必须是 \${MIN_PORT} - \${MAX_PORT}，需要连续\${NUM}个空闲的端口 \(默认为: \${START_PORT_DEFAULT}\):"
E[12]="Please enter UUID \(Default is \${UUID_DEFAULT}\):"
C[12]="请输入 UUID \(默认为 \${UUID_DEFAULT}\):"
E[13]="Please enter the node name. \(Default is \${NODE_NAME_DEFAULT}\):"
C[13]="请输入节点名称 \(默认为: \${NODE_NAME_DEFAULT}\):"
E[14]="Node name only allow uppercase and lowercase letters, numeric characters, hyphens, underscores, dots and @, please re-enter \(\${a} times remaining\):"
C[14]="节点名称只允许英文大小写、数字、连字符、下划线、点和@字符，请重新输入 \(剩余\${a}次\):"
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
E[49]="Select more protocols to install (e.g. hgbd). The order of the port numbers of the protocols is related to the ordering of the multiple choices:\n a. all (default)"
C[49]="多选需要安装协议(比如 hgbd)，协议的端口号次序与多选的排序有关:\n a. all (默认)"
E[50]="Please enter the \$TYPE domain name:"
C[50]="请输入 \$TYPE 域名:"
E[51]="Please choose or custom a cdn, http support is required:"
C[51]="请选择或输入 cdn，要求支持 http:"
E[52]="Please set the ip \[\${WS_SERVER_IP_SHOW}] to domain \[\${TYPE_HOST_DOMAIN}], and set the origin rule to \[\${TYPE_PORT_WS}] in Cloudflare."
C[52]="请在 Cloudflare 绑定 \[\${WS_SERVER_IP_SHOW}] 的域名为 \[\${TYPE_HOST_DOMAIN}], 并设置 origin rule 为 \[\${TYPE_PORT_WS}]"
E[53]="Please select or enter the preferred domain or IP, the default is \${CDN_DOMAIN[0]}:"
C[53]="请选择或者填入优选域名或 IP，默认为 \${CDN_DOMAIN[0]}:"
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
E[64]="Please select the protocols to be removed (multiple selections possible. Press Enter to skip):"
C[64]="请选择需要删除的协议（可以多选，回车跳过）:"
E[65]="(2/3) Uninstalled protocols."
C[65]="(2/3) 未安装的协议"
E[66]="Please select the protocols to be added (multiple choices possible. Press Enter to skip):"
C[66]="请选择需要增加的协议（可以多选，回车跳过）:"
E[67]="(3/3) Confirm all protocols for reloading."
C[67]="(3/3) 确认重装的所有协议"
E[68]="Press [n] if there is an error, other keys to continue:"
C[68]="如有错误请按 [n]，其他键继续:"
E[69]="Install sba scripts (argo + sing-box) [https://github.com/fscarmen/sba]"
C[69]="安装 sba 脚本 (argo + sing-box) [https://github.com/fscarmen/sba]"
E[70]="Please enter the reality private key (privateKey), skip to generate randomly:"
C[70]="请输入 reality 的密钥(privateKey)，跳过则随机生成:"
E[71]="Create shortcut [ sb ] successfully."
C[71]="创建快捷 [ sb ] 指令成功!"
E[72]="Path to each client configuration file: ${WORK_DIR}/subscribe/\n The full template can be found at:\n https://github.com/chika0801/sing-box-examples/tree/main/Tun"
C[72]="各客户端配置文件路径: ${WORK_DIR}/subscribe/\n 完整模板可参照:\n https://github.com/chika0801/sing-box-examples/tree/main/Tun"
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
E[79]="Please enter the port number of nginx. Must be \${MIN_PORT} - \${MAX_PORT} \(Default is: \${PORT_NGINX_DEFAULT}\):"
C[79]="请输入 nginx 端口号，必须是 \${MIN_PORT} - \${MAX_PORT} \(默认为: \${PORT_NGINX_DEFAULT}\):"
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
E[85]="Please enter Argo Token, Argo Json or Cloudflare API\n\n [*] Token: Visit https://dash.cloudflare.com/ , Zero Trust > Networks > Connectors > Create a tunnel > Select Cloudflared\n\n [*] Json: Users can easily obtain it through the following website: https://fscarmen.cloudflare.now.cc\n\n [*] Cloudflare API: Visit https://dash.cloudflare.com/profile/api-tokens > Create Token > Create Custom Token > Add the following permissions:\n - Account > Cloudflare One Connectors: cloudflared > Edit\n - Zone > DNS > Edit\n\n - Account Resources: Include > Required Account\n - Zone Resources: Include > Specific zone > Argo Root Domain"
C[85]="请输入 Argo Token, Argo Json 或者 Cloudflare API\n\n [*] Token: 访问 https://dash.cloudflare.com/ ，Zero Trust > 网络 > 连接器 > 创建隧道 > 选择 Cloudflared\n\n [*] Json: 用户通过以下网站轻松获取: https://fscarmen.cloudflare.now.cc\n\n [*] Cloudflare API: 访问 https://dash.cloudflare.com/profile/api-tokens > 创建令牌 > 创建自定义令牌 > 添加以下权限:\n - 帐户 > Cloudflare One连接器: Cloudflared > 编辑\n - 区域 > DNS > 编辑\n\n - 帐户资源: 包括 > 所需账户\n - 区域资源: 包括 > 特定区域 > 所需域名"
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
E[91]="Argo tunnel type:\n 1. Try\n 2. Token or Json. Including created through Cloudflare API"
C[91]="Argo 隧道类型:\n 1. Try\n 2. Token 或者 Json，包括通过 Cloudflare API 创建"
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
E[97]="Port Hopping/Multiple: Users sometimes report that their ISPs block or throttle persistent UDP connections. However, these restrictions often only apply to the specific port being used. Port hopping can be used as a workaround for this situation. This function needs to occupy multiple ports, please make sure that these ports are not listening to other services. \n Tip1: The number of ports should not be too many, the recommended number is about 1000, the minimum value: $MIN_HOPPING_PORT, the maximum value: $MAX_HOPPING_PORT.\n Tip2: nat machines have a limited number of ports to listen on, usually 20-30. If setting ports out of the nat range will cause the node to not work, please use with caution!\n This function is not used by default."
C[97]="端口跳跃/多端口(Port Hopping)介绍: 用户有时报告运营商会阻断或限速 UDP 连接。不过，这些限制往往仅限单个端口。端口跳跃可用作此情况的解决方法。该功能需要占用多个端口，请保证这些端口没有监听其他服务\n Tip1: 端口选择数量不宜过多，推荐1000个左右，最小值:$MIN_HOPPING_PORT，最大值: $MAX_HOPPING_PORT\n Tip2: nat 鸡由于可用于监听的端口有限，一般为20-30个。如设置了不开放的端口会导致节点不通，请慎用！\n 默认不使用该功能"
E[98]="Enter the port range, e.g. 50000:51000. Leave blank to disable:"
C[98]="请输入端口范围，例如 50000:51000，如要禁用请留空:"
E[99]="The \${SING_BOX_SCRIPT} is detected to be installed. Script exits."
C[99]="检测到已安装 \${SING_BOX_SCRIPT}，脚本退出!"
E[100]="Can't get the official latest version. Script exits."
C[100]="获取不到官方的最新版本，脚本退出!"
E[101]="The privateKey should be a 43-character base64url encoding; please check."
C[101]="privateKey 应该是43位的 base64url 编码，请检查"
E[102]="Backing up old version sing-box to ${WORK_DIR}/sing-box.bak"
C[102]="已备份旧版本 sing-box 到 ${WORK_DIR}/sing-box.bak"
E[103]="New version \$ONLINE is running successfully, backup file deleted"
C[103]="新版本 \$ONLINE 运行成功，已删除备份文件"
E[104]="New version failed to run \$ONLINE, restoring old version \$LOCAL ..."
C[104]="新版本 \$ONLINE 运行失败，正在恢复旧版本 \$LOCAL ..."
E[105]="Successfully restored old version \$LOCAL"
C[105]="已成功恢复旧版本 \$LOCAL"
E[106]="Failed to restore old version \$LOCAL, please check manually"
C[106]="恢复旧版本 \$LOCAL 失败，请手动检查"
E[107]="Sing-box is not installed and cannot change the CDN."
C[107]="Sing-box 未安装，不能更换 CDN"
E[108]="Change CDN"
C[108]="更换 CDN"
E[109]="Current CDN is: \${CDN_NOW}"
C[109]="当前 CDN 为: \${CDN_NOW}"
E[110]="No CDN protocol is currently in use"
C[110]="当前没有使用 CDN 的协议"
E[111]="Please select or enter a new CDN (press Enter to keep the current one):"
C[111]="请选择或输入新的 CDN (回车保持当前值):"
E[112]="CDN has been changed from \${CDN_NOW} to \${CDN_NEW}"
C[112]="CDN 已从 \${CDN_NOW} 更改为 \${CDN_NEW}"
E[113]="Failed to change CDN, using random privateKey"
C[113]="privateKey 格式失败次数过多，已使用随机私钥"
E[114]="Invalid privateKey format: expected a 43-character base64url-encoded string."
C[114]="privateKey 私钥格式错误，应该为 43位 base64url 编码"
E[115]="Quick install mode (all protocols + subscription) (sb -k)"
C[115]="极速安装模式 (所有协议 + 订阅) (sb -l)"
E[116]="Failed to generate publicKey from privateKey, using random privateKey"
C[116]="从 privateKey 生成 publicKey 失败，将使用随机公私钥"
E[117]="Continue with quick fast tunnel"
C[117]="使用临时隧道继续"
E[118]="Please enter [Token, Json, API] value:"
C[118]="请输入 [Token, Json, API] 的值:"
E[119]="Using Cloudflare API to create Tunnel and handle DNS config..."
C[119]="使用 Cloudflare API 创建 Tunnel 和处理 DNS 配置..."
E[120]="Found existing tunnel with the same name. Tunnel ID: \$EXISTING_TUNNEL_ID. Status: \$EXISTING_TUNNEL_STATUS. Overwrite? [y/N] \(default y\):"
C[120]="发现同名隧道已创建，隧道 ID: \$EXISTING_TUNNEL_ID，状态: \$EXISTING_TUNNEL_STATUS。是否覆盖? [y/N] \(默认为 y\):"
E[121]="Change preferred domain or IP (sb -d)"
C[121]="更换优选域名或 IP (sb -d)"
E[122]="Invalid access token. Please roll at https://dash.cloudflare.com/profile/api-tokens to re-generate."
C[122]="Token 访问令牌无效。请在 https://dash.cloudflare.com/profile/api-tokens 轮转，以重新获取"
E[123]="Token zone resource failed. The tunnel root domain and the authorized domain of the token are inconsistent. Please go to https://dash.cloudflare.com/profile/api-tokens to re-authorize."
C[123]="Token 区域资源获取失败，隧道的根域名和 Token 授权的域名不一致，请到 https://dash.cloudflare.com/profile/api-tokens 检查"
E[124]="API does not have enough permissions. Please check at https://dash.cloudflare.com/profile/api-tokens\n\n [*] Token: Visit https://dash.cloudflare.com/ , Zero Trust > Networks > Connectors > Create a tunnel > Select Cloudflared\n\n [*] Json: Users can easily obtain it through the following website: https://fscarmen.cloudflare.now.cc\n\n [*] Cloudflare API: Visit https://dash.cloudflare.com/profile/api-tokens > Create Token > Create Custom Token > Add the following permissions:\n - Account > Cloudflare One Connectors: cloudflared > Edit\n - Zone > DNS > Edit\n\n - Account Resources: Include > Required Account\n - Zone Resources: Include > Specific zone > Argo Root Domain"
C[124]="API 没有足够权限，请在 https://dash.cloudflare.com/profile/api-tokens 检查 Token 权限配置\n\n [*] Token: 访问 https://dash.cloudflare.com/ ，Zero Trust > 网络 > 连接器 > 创建隧道 > 选择 Cloudflared\n\n [*] Json: 用户通过以下网站轻松获取: https://fscarmen.cloudflare.now.cc\n\n [*] Cloudflare API: 访问 https://dash.cloudflare.com/profile/api-tokens > 创建令牌 > 创建自定义令牌 > 添加以下权限:\n - 帐户 > Cloudflare One连接器: Cloudflared > 编辑\n - 区域 > DNS > 编辑\n\n - 帐户资源: 包括 > 所需账户\n - 区域资源: 包括 > 特定区域 > 所需域名"
E[125]="API execution failed. Response: \$RESPONSE"
C[125]="执行 API 失败，返回: \$RESPONSE"
E[126]="Network request URL structure is wrong. Missing Zone ID"
C[126]="网络请求地址（URL）结构不对，缺少 Zone ID"

# 自定义字体彩色，read 函数
warning() { echo -e "\033[31m\033[01m$*\033[0m"; }  # 红色
error() { echo -e "\033[31m\033[01m$*\033[0m" && exit 1; } # 红色
info() { echo -e "\033[32m\033[01m$*\033[0m"; }   # 绿色
hint() { echo -e "\033[33m\033[01m$*\033[0m"; }   # 黄色
reading() { read -rp "$(info "$1")" "$2"; }
text() { grep -q '\$' <<< "${E[$*]}" && eval echo "\$(eval echo "\${${L}[$*]}")" || eval echo "\${${L}[$*]}"; }

# 检测是否需要启用 Github CDN，如能直接连通，则不使用
check_cdn() {
  # GITHUB_PROXY 数组第一个元素为空，相当于直连
  for PROXY_URL in "${GITHUB_PROXY[@]}"; do
    local PROXY_STATUS_CODE=$(wget --server-response --spider --quiet --timeout=3 --tries=1 ${PROXY_URL}https://api.github.com/repos/SagerNet/sing-box/releases 2>&1 | awk '/HTTP\//{last_field = $2} END {print last_field}')
    [ "$PROXY_STATUS_CODE" = "200" ] && GH_PROXY="$PROXY_URL" && break
  done
}

# 检测是否解锁 chatGPT，以决定是否使用 warp 链式代理或者是 direct out，此处判断改编自 https://github.com/lmc999/RegionRestrictionCheck
check_chatgpt() {
  local CHECK_STACK=-$1
  local UA_BROWSER="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"
  local UA_SEC_CH_UA='"Google Chrome";v="125", "Chromium";v="125", "Not.A/Brand";v="24"'
  wget --help | grep -q '\-\-ciphers' && local IS_CIPHERS=is_ciphers

  # 首先检查API访问
  local CHECK_RESULT1=$(wget --timeout=2 --tries=2 --retry-connrefused --waitretry=5 ${CHECK_STACK} -qO- --content-on-error --header='authority: api.openai.com' --header='accept: */*' --header='accept-language: en-US,en;q=0.9' --header='authorization: Bearer null' --header='content-type: application/json' --header='origin: https://platform.openai.com' --header='referer: https://platform.openai.com/' --header="sec-ch-ua: ${UA_SEC_CH_UA}" --header='sec-ch-ua-mobile: ?0' --header='sec-ch-ua-platform: "Windows"' --header='sec-fetch-dest: empty' --header='sec-fetch-mode: cors' --header='sec-fetch-site: same-site' --user-agent="${UA_BROWSER}" 'https://api.openai.com/compliance/cookie_requirements')

  [ -z "$CHECK_RESULT1" ] && grep -qw is_ciphers <<< "$IS_CIPHERS" && local CHECK_RESULT1=$(wget --timeout=2 --tries=2 --retry-connrefused --waitretry=5 ${CHECK_STACK} --ciphers=DEFAULT@SECLEVEL=1 --no-check-certificate -qO- --content-on-error --header='authority: api.openai.com' --header='accept: */*' --header='accept-language: en-US,en;q=0.9' --header='authorization: Bearer null' --header='content-type: application/json' --header='origin: https://platform.openai.com' --header='referer: https://platform.openai.com/' --header="sec-ch-ua: ${UA_SEC_CH_UA}" --header='sec-ch-ua-mobile: ?0' --header='sec-ch-ua-platform: "Windows"' --header='sec-fetch-dest: empty' --header='sec-fetch-mode: cors' --header='sec-fetch-site: same-site' --user-agent="${UA_BROWSER}" 'https://api.openai.com/compliance/cookie_requirements')

  # 如果API检测失败或者检测到unsupported_country,直接返回ban
  if [ -z "$CHECK_RESULT1" ] || grep -qi 'unsupported_country' <<< "$CHECK_RESULT1"; then
    echo "ban"
    return
  fi

  # API检测通过后,继续检查网页访问
  local CHECK_RESULT2=$(wget --timeout=2 --tries=2 --retry-connrefused --waitretry=5 ${CHECK_STACK} -qO- --content-on-error --header='authority: ios.chat.openai.com' --header='accept: */*;q=0.8,application/signed-exchange;v=b3;q=0.7' --header='accept-language: en-US,en;q=0.9' --header="sec-ch-ua: ${UA_SEC_CH_UA}" --header='sec-ch-ua-mobile: ?0' --header='sec-ch-ua-platform: "Windows"' --header='sec-fetch-dest: document' --header='sec-fetch-mode: navigate' --header='sec-fetch-site: none' --header='sec-fetch-user: ?1' --header='upgrade-insecure-requests: 1' --user-agent="${UA_BROWSER}" https://ios.chat.openai.com/)

  [ -z "$CHECK_RESULT2" ] && grep -qw is_ciphers <<< "$IS_CIPHERS" && local CHECK_RESULT2=$(wget --timeout=2 --tries=2 --retry-connrefused --waitretry=5 ${CHECK_STACK} --ciphers=DEFAULT@SECLEVEL=1 --no-check-certificate -qO- --content-on-error --header='authority: ios.chat.openai.com' --header='accept: */*;q=0.8,application/signed-exchange;v=b3;q=0.7' --header='accept-language: en-US,en;q=0.9' --header="sec-ch-ua: ${UA_SEC_CH_UA}" --header='sec-ch-ua-mobile: ?0' --header='sec-ch-ua-platform: "Windows"' --header='sec-fetch-dest: document' --header='sec-fetch-mode: navigate' --header='sec-fetch-site: none' --header='sec-fetch-user: ?1' --header='upgrade-insecure-requests: 1' --user-agent="${UA_BROWSER}" https://ios.chat.openai.com/)

  # 检查第二个结果
  if [ -z "$CHECK_RESULT2" ] || grep -qi 'VPN' <<< "$CHECK_RESULT2"; then
    echo "ban"
  else
    echo "unlock"
  fi
}

# 脚本当天及累计运行次数统计
statistics_of_run-times() {
  local UPDATE_OR_GET=$1
  local SCRIPT=$2
  if grep -q 'update' <<< "$UPDATE_OR_GET"; then
    { wget --no-check-certificate -qO- --timeout=3 "https://stat.cloudflare.now.cc/api/updateStats?script=${SCRIPT}" > $TEMP_DIR/statistics 2>/dev/null || true; }&
  elif grep -q 'get' <<< "$UPDATE_OR_GET"; then
    [ -s $TEMP_DIR/statistics ] && [[ $(cat $TEMP_DIR/statistics) =~ \"todayCount\":([0-9]+),\"totalCount\":([0-9]+) ]] && local TODAY="${BASH_REMATCH[1]}" && local TOTAL="${BASH_REMATCH[2]}" && rm -f $TEMP_DIR/statistics
    hint "\n*******************************************\n\n $(text 55) \n"
  fi
}

# 选择中英语言
select_language() {
  if [ -z "$L" ]; then
    if [ -s ${WORK_DIR}/language ]; then
      L=$(cat ${WORK_DIR}/language)
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

# 更换 cdn
change_cdn() {
  [ ! -d "${WORK_DIR}" ] && error " $(text 107) "

  # 检测是否有使用 CDN，方法是查找是否有 ${WORK_DIR}/conf/
  ! ls ${WORK_DIR}/conf/*-ws*inbounds.json >/dev/null 2>&1 && error " $(text 110) "
  local CDN_NOW=$(awk -F '"' '/"CDN"/{print $4; exit}' ${WORK_DIR}/conf/*-ws*inbounds.json)

  # 提示当前使用的 CDN 并让用户选择或输入新的 CDN
  hint "\n $(text 109) \n"
  for ((c=0; c<${#CDN_DOMAIN[@]}; c++)); do
    hint " $[c+1]. ${CDN_DOMAIN[c]} "
  done
  reading "\n $(text 111) " CDN_CHOOSE

  # 如果用户直接回车，保持当前 CDN。否则则选择用户输入的 CDN
  if grep -q '.' <<< "$CDN_CHOOSE"; then
    # 如果用户输入数字，选择对应的 CDN
    [[ "$CDN_CHOOSE" =~ ^[1-9][0-9]*$ && "$CDN_CHOOSE" -le "${#CDN_DOMAIN[@]}" ]] && CDN_NEW=${CDN_DOMAIN[$((CDN_CHOOSE-1))]} || CDN_NEW=$CDN_CHOOSE

    # 使用 sed 更新所有文件中的 CDN 值
    find ${WORK_DIR} -type f | xargs -P 50 sed -i "s/${CDN_NOW}/${CDN_NEW}/g"
  fi

  # 更新完成后提示并导出订阅列表
  export_list
  grep -q '.' <<< "${CDN_NEW}" && info "\n $(text 112) \n"
}

# 创建 Argo Tunnel API
create_argo_tunnel() {
  local CLOUDFLARE_API_TOKEN="$1"
  local ARGO_DOMAIN="$2"
  local SERVICE_PORT="$3"
  local TUNNEL_NAME=${ARGO_DOMAIN%%.*}
  local ROOT_DOMAIN=${ARGO_DOMAIN#*.}

  api_error() {
    local RESPONSE="$1"
    local CHECK_ZONE_ID="$2"

    if grep -q '"code":9109,' <<< "$RESPONSE"; then
      warning " $(text 122) " && sleep 2 && return 2
    elif grep -q '"code":7003,' <<< "$RESPONSE"; then
      warning " $(text 126) " && sleep 2 && return 3
    elif grep -q 'check_zone_id' <<< "$CHECK_ZONE_ID" && grep -q '"count":0,' <<< "$RESPONSE"; then
      warning " $(text 123) " && sleep 2 && return 4
    elif grep -q '"code":10000,' <<< "$RESPONSE"; then
      warning " $(text 124) " && sleep 2 && return 1
    elif grep -q '"success":true' <<< "$RESPONSE"; then
      return 0
    else
      warning " $(text 125) " && sleep 2 && return 5
    fi
  }

  # 步骤 1: 获取 Zone ID 和 Account ID
  local ZONE_RESPONSE=$(wget --no-check-certificate -qO- --content-on-error \
    --header="Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
    --header="Content-Type: application/json" \
    "https://api.cloudflare.com/client/v4/zones?name=${ROOT_DOMAIN}")

  api_error "$ZONE_RESPONSE" 'check_zone_id' || return $?

  [[ "$ZONE_RESPONSE" =~ \"id\":\"([^\"]+)\".*\"account\":\{\"id\":\"([^\"]+)\" ]] && local ZONE_ID="${BASH_REMATCH[1]}" ACCOUNT_ID="${BASH_REMATCH[2]}" || \
  return 5

  # 步骤 2: 查询并处理现有 Tunnel
  local TUNNEL_LIST=$(wget --no-check-certificate -qO- --content-on-error \
    --header="Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
    --header="Content-Type: application/json" \
    "https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/cfd_tunnel?is_deleted=false")

  api_error "$TUNNEL_LIST" || return $?

  local TUNNEL_LIST_SPLIT=$(awk 'BEGIN{RS="";FS=""}{s=substr($0,index($0,"\"result\":[")+10);d=0;b="";for(i=1;i<=length(s);i++){c=substr(s,i,1);if(c=="{")d++;if(d>0)b=b c;if(c=="}"){d--;if(d==0){print b;b=""}}}}' <<< "$TUNNEL_LIST")

  # 检查是否存在同名 Tunnel
  while true; do
    unset TUNNEL_CHECK EXISTING_TUNNEL_ID EXISTING_TUNNEL_STATUS
    local TUNNEL_CHECK=$(grep '\"name\":\"'$TUNNEL_NAME'\"' <<< "$TUNNEL_LIST_SPLIT")
    if [[ "$TUNNEL_CHECK" =~ \"id\":\"([^\"]+)\".*\"status\":\"([^\"]+)\" ]]; then
      local EXISTING_TUNNEL_ID=${BASH_REMATCH[1]} EXISTING_TUNNEL_STATUS=${BASH_REMATCH[2]}
      # 处理状态显示的本地化
      grep -qw 'C' <<< "$L" && EXISTING_TUNNEL_STATUS=$(sed 's/inactive/停用（未激活）/; s/down/离线/; s/healthy/连接中/; s/degraded/降级/ ' <<< "$EXISTING_TUNNEL_STATUS")
      reading "\n $(text 120) " OVERWRITE
      if grep -qw 'n' <<< "${OVERWRITE,,}"; then
        # 询问用户输入另一个域名前缀
        unset ARGO_DOMAIN
        reading "\n $(text 87) " ARGO_DOMAIN

        # 用户直接回车，使用临时域名，退出当前流程
        ! grep -q '\.' <<< "$ARGO_DOMAIN" && return 5

        # 更新TUNNEL_NAME和ROOT_DOMAIN，循环会自动检查新名称
        TUNNEL_NAME=${ARGO_DOMAIN%%.*}
        ROOT_DOMAIN=${ARGO_DOMAIN#*.}
      else
        # 用户选择覆盖，则跳出循环继续执行创建流程
        break
      fi
    else
      # 如果新域名不存在，则跳出循环继续执行创建流程
      unset TUNNEL_CHECK EXISTING_TUNNEL_ID EXISTING_TUNNEL_STATUS
      break
    fi
  done

  # 如果同名 Tunnel 不存在，则先创建
  if grep -q '^$' <<< "$EXISTING_TUNNEL_ID"; then
    # 生成 Tunnel Secret (至少 32 字节的 base64 编码)
    local TUNNEL_SECRET=$(openssl rand -base64 32)

    # 创建新 Tunnel
    local CREATE_RESPONSE=$(wget --no-check-certificate -qO- --content-on-error \
      --header="Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
      --header="Content-Type: application/json" \
      --post-data="{
        \"name\": \"$TUNNEL_NAME\",
        \"config_src\": \"cloudflare\",
        \"tunnel_secret\": \"$TUNNEL_SECRET\"
      }" \
      "https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/cfd_tunnel")

    api_error "$CREATE_RESPONSE" || return $?

    [[ $CREATE_RESPONSE =~ \"id\":\"([^\"]+)\".*\"token\":\"([^\"]+)\" ]] && \
    local TUNNEL_ID=${BASH_REMATCH[1]} TUNNEL_TOKEN=${BASH_REMATCH[2]} || \
    return 5
  else
    # 如果有同名 Tunnel (EXISTING_TUNNEL_ID 非空），则获取其 TOKEN
    local EXISTING_TUNNEL_TOKEN=$(wget -qO- --content-on-error \
      --header="Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
      --header="Content-Type: application/json" \
      "https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/cfd_tunnel/${EXISTING_TUNNEL_ID}/token")

    api_error "$EXISTING_TUNNEL_TOKEN" || return $?

    local TUNNEL_ID=$EXISTING_TUNNEL_ID \
    TUNNEL_TOKEN=$(sed -n 's/.*"result":"\([^"]\+\)".*/\1/p' <<< "$EXISTING_TUNNEL_TOKEN") && \
    TUNNEL_SECRET=$(base64 -d <<< "$TUNNEL_TOKEN" | sed 's/.*"s":"\([^"]\+\)".*/\1/') || \
    return 5
  fi

  # 步骤 3: 配置 Tunnel ingress 规则... 不管原来的规则，一率覆盖处理
 local CONFIG_RESPONSE=$(wget --no-check-certificate -qO- --content-on-error \
  --method=PUT \
  --header="Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  --header="Content-Type: application/json" \
  --body-data="{
    \"config\": {
      \"ingress\": [
        {
          \"service\": \"http://localhost:${SERVICE_PORT}\",
          \"hostname\": \"${ARGO_DOMAIN}\"
        },
        {
          \"service\": \"http_status:404\"
        }
      ],
      \"warp-routing\": {
        \"enabled\": false
      }
    }
  }" \
  "https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/cfd_tunnel/${TUNNEL_ID}/configurations")

  api_error "$CONFIG_RESPONSE" || return $?

  # 步骤 4: 管理 DNS 记录
  local DNS_PAYLOAD="{
    \"name\": \"${ARGO_DOMAIN}\",
    \"type\": \"CNAME\",
    \"content\": \"${TUNNEL_ID}.cfargotunnel.com\",
    \"proxied\": true,
    \"settings\": {
      \"flatten_cname\": false
    }
  }"

  local DNS_LIST=$(wget --no-check-certificate -qO- --content-on-error \
    --header="Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
    --header="Content-Type: application/json" \
    "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?type=CNAME&name=${ARGO_DOMAIN}")

  api_error "$DNS_LIST" || return $?

  # 如果已存在需要的 DNS 记录，就跳过
  if [[ "$DNS_LIST" =~ \"id\":\"([^\"]+)\".*\"$ARGO_DOMAIN\".*\"content\":\"([^\"]+)\" ]]; then
    local EXISTING_DNS_ID="${BASH_REMATCH[1]}" EXISTED_DNS_CONTENT="${BASH_REMATCH[2]}"

    # DNS 记录与隧道 ID 不匹配的话，覆盖原来的 CNAME 记录
    if ! grep -qw "$EXISTING_TUNNEL_ID" <<< "${EXISTED_DNS_CONTENT%%.*}"; then
      local DNS_RESPONSE=$(wget --no-check-certificate -qO- --content-on-error \
        --method=PATCH \
        --header="Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
        --header="Content-Type: application/json" \
        --body-data="$DNS_PAYLOAD" \
        "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${EXISTING_DNS_ID}")

      api_error "$DNS_RESPONSE" || return $?
    fi
  else
    # 未找到现有 DNS 记录，使用 POST 创建
    local DNS_RESPONSE=$(wget --no-check-certificate -qO- --content-on-error \
      --method=POST \
      --header="Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
      --header="Content-Type: application/json" \
      --body-data="$DNS_PAYLOAD" \
      "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records")

    api_error "$DNS_RESPONSE" || return $?
  fi

  # 返回 Argo Tunnel Token 或者 Json
  ARGO_JSON="{\"AccountTag\":\"$ACCOUNT_ID\",\"TunnelSecret\":\"$TUNNEL_SECRET\",\"TunnelID\":\"$TUNNEL_ID\",\"Endpoint\":\"\"}"
  ARGO_TOKEN="$TUNNEL_TOKEN"
}

# 输入 Nginx 服务端口
input_nginx_port() {
  local NUM=$1
  local PORT_ERROR_TIME=6
  # 生成 1000 - 65535 随机默认端口数
  local PORT_NGINX_DEFAULT=$(shuf -i ${MIN_PORT}-${MAX_PORT} -n 1)
  [[ "$IS_FAST_INSTALL" = 'is_fast_install' && -z "$PORT_NGINX" ]] && PORT_NGINX="$PORT_NGINX_DEFAULT"
  while true; do
    [[ "$PORT_ERROR_TIME" > 1 && "$PORT_ERROR_TIME" < 6 ]] && unset IN_USED PORT_NGINX
    (( PORT_ERROR_TIME-- )) || true
    if [ "$PORT_ERROR_TIME" = 0 ]; then
      error "\n $(text 3) \n"
    else
      [ -z "$PORT_NGINX" ] && reading "\n (3/6) $(text 79) " PORT_NGINX
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
    if [ -z "$PORT_HOPPING_RANGE" ]; then
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
    fi
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

# 输入 Reality 密钥
input_reality_key() {
  [[ "$NONINTERACTIVE_INSTALL" != 'noninteractive_install' && "$IS_FAST_INSTALL" != 'is_fast_install' ]] && [ -z "$REALITY_PRIVATE" ] && reading "\n $(text 70) " REALITY_PRIVATE
  [ -z "$REALITY_PRIVATE" ] && unset REALITY_PRIVATE && return

  local PRIVATEKEY_ERROR_TIME=5
  until [[ "$REALITY_PRIVATE" =~ ^[A-Za-z0-9_-]{43}$ || -z "$REALITY_PRIVATE" ]]; do
    (( PRIVATEKEY_ERROR_TIME-- )) || true
    [ "$PRIVATEKEY_ERROR_TIME" = 0 ] && unset REALITY_PRIVATE && hint "\n $(text 113) \n" && break
    warning "\n $(text 114) "
    reading "\n $(text 70) " REALITY_PRIVATE
    # 即使 REALITY_PRIVATE 为空值，但 REALITY_PRIVATE 数组数量 ${REALITY_PRIVATE[@]} 为 1，影响后续的处理，所以要置空
    [ -z "$REALITY_PRIVATE" ] && unset REALITY_PRIVATE && break
  done
}

# 输入 Argo 域名和认证信息
input_argo_auth() {
  local IS_CHANGE_ARGO=$1
  [ -n "$IS_CHANGE_ARGO" ] && local EMPTY_ERROR_TIME=5
  local DOMAIN_ERROR_TIME=6 ARGO_AUTH_LENGTH=40

  # 处理可能输入的错误，去掉开头和结尾的空格，去掉最后的 :
  if [ "$IS_CHANGE_ARGO" = 'is_change_argo' ]; then
    until [ -n "$ARGO_DOMAIN" ]; do
      (( EMPTY_ERROR_TIME-- )) || true
      [ "$EMPTY_ERROR_TIME" = 0 ] && error "\n $(text 3) \n"
      reading "\n $(text 88) " ARGO_DOMAIN
      [ -n "$IS_CHANGE_ARGO" ] && ARGO_DOMAIN=$(sed 's/[ ]*//g; s/:[ ]*//' <<< "$ARGO_DOMAIN")
    done
  elif [[ "$NONINTERACTIVE_INSTALL" != 'noninteractive_install' && "$IS_FAST_INSTALL" != 'is_fast_install' ]]; then
    [ -z "$ARGO_DOMAIN" ] && reading "\n $(text 87) " ARGO_DOMAIN
    ARGO_DOMAIN=$(sed 's/[ ]*//g; s/:[ ]*//' <<< "$ARGO_DOMAIN")
  fi

  if [[ -z "$ARGO_DOMAIN" && ( "$ARGO_DOMAIN" =~ trycloudflare\.com$ || "$IS_CHANGE_ARGO" = 'is_add_protocols' || "$IS_CHANGE_ARGO" = 'is_install' || "$NONINTERACTIVE_INSTALL" = 'noninteractive_install' ) ]]; then
    ARGO_RUNS="${WORK_DIR}/cloudflared tunnel --edge-ip-version auto --no-autoupdate --url http://localhost:$PORT_NGINX"
  elif [ -n "${ARGO_DOMAIN}" ]; then
    if [ -z "${ARGO_AUTH}" ]; then
      until [[ "$ARGO_AUTH" =~ TunnelSecret || "$ARGO_AUTH" =~ [A-Z0-9a-z=]{150,250}$ || "${#ARGO_AUTH}" = $ARGO_AUTH_LENGTH ]]; do
        [ "$DOMAIN_ERROR_TIME" != 6 ] && warning "\n $(text 86) \n"
      (( DOMAIN_ERROR_TIME-- )) || true
        [ "$DOMAIN_ERROR_TIME" != 0 ] && hint "\n $(text 85) \n " && reading "\n $(text 118) " ARGO_AUTH || error "\n $(text 3) \n"
      done
    fi

    # 根据 ARGO_AUTH 的内容，自行判断是 Json， Token 还是 API 申请
    if [[ "$ARGO_AUTH" =~ TunnelSecret ]]; then
      ARGO_TYPE=is_json_argo
      ARGO_JSON=${ARGO_AUTH//[ ]/}
      [ "$IS_CHANGE_ARGO" = 'is_install' ] && export_argo_json_file $TEMP_DIR || export_argo_json_file ${WORK_DIR}
      ARGO_RUNS="${WORK_DIR}/cloudflared tunnel --edge-ip-version auto --config ${WORK_DIR}/tunnel.yml run"
    elif [[ "${ARGO_AUTH}" =~ [A-Z0-9a-z=]{150,250}$ ]]; then
      ARGO_TYPE=is_token_argo
      ARGO_TOKEN=$(awk '{print $NF}' <<< "$ARGO_AUTH")
      ARGO_RUNS="${WORK_DIR}/cloudflared tunnel --edge-ip-version auto run --token ${ARGO_TOKEN}"
    elif [[ "${#ARGO_AUTH}" = $ARGO_AUTH_LENGTH ]]; then
      hint "\n $(text 119) \n "
      create_argo_tunnel "${ARGO_AUTH}" "${ARGO_DOMAIN}" "${PORT_NGINX}"
      if [[ "$ARGO_JSON" =~ TunnelSecret ]]; then
        ARGO_TYPE=is_json_argo
        [ "$IS_CHANGE_ARGO" = 'is_install' ] && export_argo_json_file $TEMP_DIR || export_argo_json_file ${WORK_DIR}
        ARGO_RUNS="${WORK_DIR}/cloudflared tunnel --edge-ip-version auto --config ${WORK_DIR}/tunnel.yml run"
      elif [ "${#ARGO_TOKEN}" = 180 ]; then
        ARGO_TYPE=is_token_argo
        ARGO_RUNS="${WORK_DIR}/cloudflared tunnel --edge-ip-version auto run --token ${ARGO_TOKEN}"
      else
        # 创建隧道失败，回退到使用临时隧道
        hint "\n $(text 117) \n "
        unset ARGO_DOMAIN
        ARGO_RUNS="${WORK_DIR}/cloudflared tunnel --edge-ip-version auto --no-autoupdate --url http://localhost:$PORT_NGINX"
      fi
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

  # 根据系统类型检查 Argo 服务配置
  local ARGO_CONFIG=$(grep -E '^(command_args=|ExecStart=)' ${ARGO_DAEMON_FILE})

  case "$ARGO_CONFIG" in
    *--config* )
      ARGO_TYPE='Json'
      ;;
    *--token* )
      ARGO_TYPE='Token'
      ;;
    * )
      ARGO_TYPE='Try'
      cmd_systemctl enable argo && sleep 2 && cmd_systemctl status argo &>/dev/null && fetch_quicktunnel_domain
  esac

  fetch_nodes_value
  hint "\n $(text 90) \n"
  unset ARGO_DOMAIN
  hint " $(text 91) \n" && reading " $(text 24) " CHANGE_TO

  case "$CHANGE_TO" in
    1 )
      cmd_systemctl disable argo
      [ -s ${WORK_DIR}/tunnel.json ] && rm -f ${WORK_DIR}/tunnel.{json,yml}

      # 根据系统类型修改配置文件
      [ "$SYSTEM" = 'Alpine' ] && sed -i "s@^command_args=.*@command_args=\"--edge-ip-version auto --no-autoupdate --url http://localhost:$PORT_NGINX\"@g" ${ARGO_DAEMON_FILE} || sed -i "s@ExecStart=.*@ExecStart=${WORK_DIR}/cloudflared tunnel --edge-ip-version auto --no-autoupdate --url http://localhost:$PORT_NGINX@g" ${ARGO_DAEMON_FILE}
      ;;
    2 )
      [ -s ${WORK_DIR}/tunnel.json ] && rm -f ${WORK_DIR}/tunnel.{json,yml}
      input_argo_auth is_change_argo
      cmd_systemctl disable argo

      if [ -n "$ARGO_TOKEN" ]; then
        [ "$SYSTEM" = 'Alpine' ] && sed -i "s@^command_args=.*@command_args=\"--edge-ip-version auto run --token ${ARGO_TOKEN}\"@g" ${ARGO_DAEMON_FILE} || sed -i "s@ExecStart=.*@ExecStart=${WORK_DIR}/cloudflared tunnel --edge-ip-version auto run --token ${ARGO_TOKEN}@g" ${ARGO_DAEMON_FILE}
      elif [ -n "$ARGO_JSON" ]; then
        [ "$SYSTEM" = 'Alpine' ] && sed -i "s@^command_args=.*@command_args=\"--edge-ip-version auto --config ${WORK_DIR}/tunnel.yml run\"@g" ${ARGO_DAEMON_FILE} || sed -i "s@ExecStart=.*@ExecStart=${WORK_DIR}/cloudflared tunnel --edge-ip-version auto --config ${WORK_DIR}/tunnel.yml run@g" ${ARGO_DAEMON_FILE}
      fi

      # 更新相关配置文件中的域名
      [ -s ${WORK_DIR}/conf/17_${NODE_TAG[6]}_inbounds.json ] && sed -i "s/VMESS_HOST_DOMAIN.*/VMESS_HOST_DOMAIN\": \"$ARGO_DOMAIN\"/" ${WORK_DIR}/conf/17_${NODE_TAG[6]}_inbounds.json
      [ -s ${WORK_DIR}/conf/18_${NODE_TAG[7]}_inbounds.json ] && sed -i "s/\"server_name\":.*/\"server_name\": \"$ARGO_DOMAIN\",/" ${WORK_DIR}/conf/18_${NODE_TAG[7]}_inbounds.json
      ;;
    * )
      exit 0
  esac

  # 启用 Argo 服务
  cmd_systemctl enable argo

  # 更新节点信息和配置
  fetch_nodes_value
  export_nginx_conf_file
  export_list
}

check_root() {
  [ "$(id -u)" != 0 ] && error "\n $(text 43) \n"
}

# 判断处理器架构
check_arch() {
  [ "$SYSTEM" = 'Alpine' ] && local IS_MUSL='-musl'

  case "$(uname -m)" in
    aarch64|arm64 )
      SING_BOX_ARCH=arm64${IS_MUSL}; JQ_ARCH=arm64; QRENCODE_ARCH=arm64; ARGO_ARCH=arm64
      ;;
    x86_64|amd64 )
      SING_BOX_ARCH=amd64${IS_MUSL}; JQ_ARCH=amd64; QRENCODE_ARCH=amd64; ARGO_ARCH=amd64
      ;;
    armv7l )
      SING_BOX_ARCH=armv7${IS_MUSL}; JQ_ARCH=armhf; QRENCODE_ARCH=arm; ARGO_ARCH=arm
      ;;
    * )
      error " $(text 25) "
  esac
}

# 检查系统是否已经安装 tcp-brutal
check_brutal() {
  IS_BRUTAL=false && [ -x "$(type -p lsmod)" ] && lsmod 2>/dev/null | grep -q 'brutal' && IS_BRUTAL=true
  [ "$IS_BRUTAL" = 'false' ] && [ -x "$(type -p modprobe)" ] && modprobe brutal 2>/dev/null && IS_BRUTAL=true
}

# 查安装及运行状态，下标0: sing-box，下标1: argo，下标2: nginx；状态码: 26 未安装， 27 已安装未运行， 28 运行中
check_install() {
  local PS_LIST=$(ps -eo pid,args | grep -E "$WORK_DIR.*([s]ing-box|[c]loudflared|[n]ginx)" | sed 's/^[ ]\+//g')

  [[ "$IS_SUB" = 'is_sub' || -s ${WORK_DIR}/subscribe/qr ]] && IS_SUB=is_sub || IS_SUB=no_sub
  if ls ${WORK_DIR}/conf/*${NODE_TAG[1]}_inbounds.json >/dev/null 2>&1; then
    check_port_hopping_nat
    [ -n "$PORT_HOPPING_END" ] && IS_HOPPING=is_hopping || IS_HOPPING=no_hopping
  fi

  if [ "$SYSTEM" = 'Alpine' ]; then
    # Alpine 系统使用 OpenRC 检查服务
    if [ -s ${SINGBOX_DAEMON_FILE} ]; then
      local OPENRC_EXECSTART=$(grep '^command=' ${SINGBOX_DAEMON_FILE})
      case "$OPENRC_EXECSTART" in
        *"${WORK_DIR}/sing-box"* )
          if rc-service sing-box status &>/dev/null; then
            STATUS[0]=$(text 28)
          else
            STATUS[0]=$(text 27)
          fi
          ;;
        * )
          SING_BOX_SCRIPT='Unknown or customized sing-box' && error "\n $(text 99) \n"
      esac
    else
      STATUS[0]=$(text 26)
    fi
  else
    # 非 Alpine 系统使用 systemd 检查服务
    if [ -s ${SINGBOX_DAEMON_FILE} ]; then
      SYSTEMD_EXECSTART=$(grep '^ExecStart=' ${SINGBOX_DAEMON_FILE})
      case "$SYSTEMD_EXECSTART" in
        'ExecStart=/etc/sing-box/sing-box run -C /etc/sing-box/conf/' | 'ExecStart=/etc/sing-box/sing-box run -C /etc/sing-box/conf' )
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
          # 检查是否是自己的脚本安装的，但路径略有不同
          if [[ "$SYSTEMD_EXECSTART" =~ "ExecStart=/etc/sing-box/sing-box run" ]]; then
            [ "$(systemctl is-active sing-box)" = 'active' ] && STATUS[0]=$(text 28) || STATUS[0]=$(text 27)
          else
            SING_BOX_SCRIPT='Unknown or customized sing-box' && error "\n $(text 99) \n"
          fi
      esac
    elif [ -s /lib/systemd/system/sing-box.service ]; then
      SYSTEMD_EXECSTART=$(grep '^ExecStart=' /lib/systemd/system/sing-box.service)
      case "$SYSTEMD_EXECSTART" in
        'ExecStart=/etc/sing-box/bin/sing-box run -c /etc/sing-box/config.json -C /etc/sing-box/conf' )
          SING_BOX_SCRIPT='233boy/sing-box' && error "\n $(text 99) \n"
          ;;
        * )
          # 检查是否是自己的脚本安装的，但路径略有不同
          if [[ "$SYSTEMD_EXECSTART" =~ "ExecStart=/etc/sing-box/sing-box run" ]]; then
            [ "$(systemctl is-active sing-box)" = 'active' ] && STATUS[0]=$(text 28) || STATUS[0]=$(text 27)
          else
            SING_BOX_SCRIPT='Unknown or customized sing-box' && error "\n $(text 99) \n"
          fi
      esac
    else
      STATUS[0]=$(text 26)
    fi
  fi

  # 如果有需要，后台静默下载 sing-box
  if [ "${STATUS[0]}" = "$(text 26)" ] && [ ! -s ${WORK_DIR}/sing-box ]; then
    {
      # 获取需要下载的 sing-box 版本
      local ONLINE=$(get_sing_box_version)
      wget --no-check-certificate --continue ${GH_PROXY}https://github.com/SagerNet/sing-box/releases/download/v$ONLINE/sing-box-$ONLINE-linux-$SING_BOX_ARCH.tar.gz -qO- | tar xz -C $TEMP_DIR sing-box-$ONLINE-linux-$SING_BOX_ARCH/sing-box >/dev/null 2>&1
      [ -s $TEMP_DIR/sing-box-$ONLINE-linux-$SING_BOX_ARCH/sing-box ] && mv $TEMP_DIR/sing-box-$ONLINE-linux-$SING_BOX_ARCH/sing-box $TEMP_DIR
      wget --no-check-certificate --continue -qO $TEMP_DIR/jq ${GH_PROXY}https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-$JQ_ARCH >/dev/null 2>&1 && chmod +x $TEMP_DIR/jq >/dev/null 2>&1
      wget --no-check-certificate --continue -qO $TEMP_DIR/qrencode ${GH_PROXY}https://github.com/fscarmen/client_template/raw/main/qrencode-go/qrencode-go-linux-$QRENCODE_ARCH >/dev/null 2>&1 && chmod +x $TEMP_DIR/qrencode >/dev/null 2>&1
    }&
  elif [ "${STATUS[0]}" != "$(text 26)" ]; then
    # 查 sing-box 进程号，运行时长和内存占用，占用的端口
    SING_BOX_VERSION="Version: $(${WORK_DIR}/sing-box version | awk '/version/{print $NF}')"
    [ "${STATUS[0]}" = "$(text 28)" ] && SING_BOX_PID=$(awk '/sing-box run/{print $1}' <<< "$PS_LIST") && [[ "$SING_BOX_PID" =~ ^[0-9]+$ ]] && SING_BOX_MEMORY_USAGE="$(text 58): $(awk '/VmRSS/{printf "%.1f\n", $2/1024}' /proc/$SING_BOX_PID/status) MB"

    NOW_PORTS=$(awk -F ':|,' '/listen_port/{print $2}' ${WORK_DIR}/conf/*)
    NOW_START_PORT=$(awk 'NR == 1 { min = $0 } { if ($0 < min) min = $0; count++ } END {print min}' <<< "$NOW_PORTS")
    NOW_CONSECUTIVE_PORTS=$(awk 'END { print NR }' <<< "$NOW_PORTS")
  fi

  if [ "$NONINTERACTIVE_INSTALL" != 'noninteractive_install' ]; then
    # 检查 Argo 服务状态
    STATUS[1]=$(text 26) && IS_ARGO=no_argo
    [ -s ${ARGO_DAEMON_FILE} ] && IS_ARGO=is_argo && STATUS[1]=$(text 27)
    cmd_systemctl status argo &>/dev/null && STATUS[1]=$(text 28)
  fi

  # 检查 Argo 服务类型
  if [ "$SYSTEM" = 'Alpine' ]; then
    if [ -s ${ARGO_DAEMON_FILE} ]; then
      local ARGO_CONTENT=$(grep '^command_args=' ${ARGO_DAEMON_FILE})
      if grep -q '\--token' <<< "$ARGO_CONTENT"; then
        ARGO_TYPE=is_token_argo
      elif grep -q '\--config' <<< "$ARGO_CONTENT"; then
        ARGO_TYPE=is_json_argo
      elif grep -q '\--url' <<< "$ARGO_CONTENT"; then
        ARGO_TYPE=is_quicktunnel_argo
      fi
    fi
  else
    if [ -s ${ARGO_DAEMON_FILE} ]; then
      local ARGO_CONTENT=$(grep '^ExecStart' ${ARGO_DAEMON_FILE})
      if grep -q '\--token' <<< "$ARGO_CONTENT"; then
        ARGO_TYPE=is_token_argo
      elif grep -q '\--config' <<< "$ARGO_CONTENT"; then
        ARGO_TYPE=is_json_argo
      elif grep -q '\--url' <<< "$ARGO_CONTENT"; then
        ARGO_TYPE=is_quicktunnel_argo
      fi
    fi
  fi

  # 如果有需要，后台静默下载 cloudflared
  if [[ "${STATUS[1]}" = "$(text 26)" || "$NONINTERACTIVE_INSTALL" = 'noninteractive_install' ]] && [ ! -s ${WORK_DIR}/cloudflared ]; then
    {
      wget --no-check-certificate -qO $TEMP_DIR/cloudflared ${GH_PROXY}https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$ARGO_ARCH >/dev/null 2>&1 && chmod +x $TEMP_DIR/cloudflared >/dev/null 2>&1
    }&
  elif [ "${STATUS[1]}" != "$(text 26)" ]; then
    # 查 Argo 进程号，运行时长和内存占用
    ARGO_VERSION=$(${WORK_DIR}/cloudflared -v | awk '{print $3}' | sed "s@^@Version: &@g")
    [ "${STATUS[1]}" = "$(text 28)" ] && ARGO_PID=$(awk '/cloudflared/{print $1}' <<< "$PS_LIST") && [[ "$ARGO_PID" =~ ^[0-9]+$ ]] && ARGO_MEMORY_USAGE="$(text 58): $(awk '/VmRSS/{printf "%.1f\n", $2/1024}' /proc/$ARGO_PID/status) MB"
  fi

  # 检查 Nginx 状态
  if [ ! -x "$(type -p nginx)" ]; then
    STATUS[2]=$(text 26)
  elif [ -s ${WORK_DIR}/nginx.conf ]; then
    # 查 Nginx 进程号，运行时长和内存占用
    NGINX_VERSION=$(nginx -v 2>&1 | sed "s#.*/#Version: #")
    NGINX_PID=$(awk '/nginx/{print $1}' <<< "${PS_LIST}")
    if [[ "$NGINX_PID" =~ ^[0-9]+$ ]]; then
      STATUS[2]=$(text 28)
      NGINX_MEMORY_USAGE="$(text 58): $(awk '/VmRSS/{printf "%.1f\n", $2/1024}' /proc/$NGINX_PID/status) MB"
    else
      STATUS[2]=$(text 27)
    fi
  else
    STATUS[2]=$(text 27)
  fi
}

# 为了适配 alpine，定义 cmd_systemctl 的函数
cmd_systemctl() {
  nginx_run() {
    $(type -p nginx) -c $WORK_DIR/nginx.conf
  }

  nginx_stop() {
    local NGINX_PID=$(ps -eo pid,args | awk -v work_dir="$WORK_DIR" '$0~(work_dir"/nginx.conf"){print $1;exit}')
    ss -nltp | sed -n "/pid=$NGINX_PID,/ s/,/ /gp" | grep -oP 'pid=\K\S+' | sort -u | xargs kill -9 >/dev/null 2>&1
  }

  if [ "$SYSTEM" = 'Alpine' ]; then
    case "$1" in
      enable )
        rc-update add "$2" default >/dev/null 2>&1
        rc-service "$2" start >/dev/null 2>&1
        ;;
      disable )
        rc-service "$2" stop >/dev/null 2>&1
        rc-update del "$2" default >/dev/null 2>&1
        ;;
      restart )
        rc-service "$2" restart >/dev/null 2>&1
        ;;
      status )
        rc-service "$2" status
        ;;
    esac
  else
    systemctl daemon-reload
    case "$1" in
      enable | disable )
        systemctl "$1" --now "$2" >/dev/null 2>&1
        if [ "$IS_CENTOS" = 'CentOS7' ] && [ "$2" = 'sing-box' ] && [ -s $WORK_DIR/nginx.conf ]; then
          if [ "$1" = 'enable' ]; then
            nginx_run
            firewall_configuration open
          else
            nginx_stop
            firewall_configuration close
          fi
        fi
        ;;
      restart )
        [ "$IS_CENTOS" = 'CentOS7' ] && [ "$2" = 'sing-box' ] && [ -s $WORK_DIR/nginx.conf ] && { nginx_stop; firewall_configuration close; }
        systemctl restart "$2" >/dev/null 2>&1
        [ "$IS_CENTOS" = 'CentOS7' ] && [ "$2" = 'sing-box' ] && [ -s $WORK_DIR/nginx.conf ] && { nginx_run; firewall_configuration open; }
        ;;
      status )
        systemctl is-active "$2"
        ;;
      * )
        systemctl "$@" >/dev/null 2>&1
        ;;
    esac
  fi
}

check_system_info() {
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
  [[ "$(sed -E 's/[^0-9.]//g; s/\..*//' <<< "$SYS")" -lt "${MAJOR[int]}" ]] && error " $(text 6) "

  # 针对部分系统作特殊处理，CentOS7 使用 yum，以上使用 dnf
  ARGO_DAEMON_FILE='/etc/systemd/system/argo.service'; SINGBOX_DAEMON_FILE='/etc/systemd/system/sing-box.service'
  if [ "$SYSTEM" = 'CentOS' ]; then
    IS_CENTOS="CentOS$(sed -E 's/[^0-9.]//g; s/\..*//' <<< "$SYS")"
    [ "$IS_CENTOS" != 'CentOS7' ] && int=5
  elif [ "$SYSTEM" = 'Alpine' ]; then
    ARGO_DAEMON_FILE='/etc/init.d/argo'; SINGBOX_DAEMON_FILE='/etc/init.d/sing-box'
  fi

  # 判断虚拟化
  if [ -x "$(type -p systemd-detect-virt)" ]; then
    VIRT=$(systemd-detect-virt)
  elif grep -qa container= /proc/1/environ 2>/dev/null; then
    VIRT=$(tr '\0' '\n' </proc/1/environ | awk -F= '/container=/{print $2; exit}')
  elif grep -Eq '(lxc|docker|kubepods|containerd)' /proc/1/cgroup 2>/dev/null; then
    VIRT=$(grep -Eo '(lxc|docker|kubepods|containerd)' /proc/1/cgroup | sed -n 1p)
  elif [ -x "$(type -p hostnamectl)" ]; then
    VIRT=$(hostnamectl | awk '/Virtualization/{print $NF}')
  else
    [ -x "$(type -p virt-what)" ] && ${PACKAGE_INSTALL[int]} virt-what >/dev/null 2>&1
    [ -x "$(type -p virt-what)" ] && VIRT=$(virt-what | sed -n 1p) || VIRT=unknown
  fi
}

# 获取 sing-box 最新版本
get_sing_box_version() {
  # FORCE_VERSION 用于在 sing-box 某个主程序出现 bug 时，强制为指定版本，以防止运行出错
  local FORCE_VERSION=$(wget --no-check-certificate --tries=2 --timeout=3 -qO- ${GH_PROXY}https://raw.githubusercontent.com/fscarmen/sing-box/refs/heads/main/force_version | sed 's/^[vV]//g; s/\r//g')
  if grep -q '.' <<< "$FORCE_VERSION"; then
    local RESULT_VERSION="$FORCE_VERSION"
  else
    # 先判断 github api 返回 http 状态码是否为 200，有时候 IP 会被限制，导致获取不到最新版本
    local API_RESPONSE=$(wget --no-check-certificate --server-response --tries=2 --timeout=3 -qO- "${GH_PROXY}https://api.github.com/repos/SagerNet/sing-box/releases" 2>&1 | grep -E '^[ ]+HTTP/|tag_name')
    if grep -q 'HTTP.* 200' <<< "$API_RESPONSE"; then
      local VERSION_LATEST=$(awk -F '["v-]' '/tag_name/{print $5}' <<< "$API_RESPONSE" | sort -Vr | sed -n '1p')
      local RESULT_VERSION=$(wget --no-check-certificate --tries=2 --timeout=3 -qO- ${GH_PROXY}https://api.github.com/repos/SagerNet/sing-box/releases | awk -F '["v]' -v var="tag_name.*$VERSION_LATEST" '$0 ~ var {print $5; exit}')
    else
      local RESULT_VERSION="$DEFAULT_NEWEST_VERSION"
    fi
  fi
  echo "$RESULT_VERSION"
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

# 查端口跳跃的 dnat 端口
check_port_hopping_nat() {
  PORT_HOPPING_TARGET=$(awk -F [:,] '/"listen_port"/{print $2}' ${WORK_DIR}/conf/*${NODE_TAG[1]}_inbounds.json)
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
  [ "$L" = 'C' ] && local IS_CHINESE='?lang=zh-CN'
  local DEFAULT_LOCAL_INTERFACE4=$(ip -4 route show default | awk '/default/ {for (i=0; i<NF; i++) if ($i=="dev") {print $(i+1); exit}}')
  local DEFAULT_LOCAL_INTERFACE6=$(ip -6 route show default | awk '/default/ {for (i=0; i<NF; i++) if ($i=="dev") {print $(i+1); exit}}')
  if [ -n ""${DEFAULT_LOCAL_INTERFACE4}${DEFAULT_LOCAL_INTERFACE6}"" ]; then
    local DEFAULT_LOCAL_IP4=$(ip -4 addr show $DEFAULT_LOCAL_INTERFACE4 | sed -n 's#.*inet \([^/]\+\)/[0-9]\+.*global.*#\1#gp')
    local DEFAULT_LOCAL_IP6=$(ip -6 addr show $DEFAULT_LOCAL_INTERFACE6 | sed -n 's#.*inet6 \([^/]\+\)/[0-9]\+.*global.*#\1#gp')
    [ -n "$DEFAULT_LOCAL_IP4" ] && local BIND_ADDRESS4="--bind-address=$DEFAULT_LOCAL_IP4"
    [ -n "$DEFAULT_LOCAL_IP6" ] && local BIND_ADDRESS6="--bind-address=$DEFAULT_LOCAL_IP6"
  fi

  local IP4_JSON=$(wget $BIND_ADDRESS4 -4 -qO- --no-check-certificate --tries=2 --timeout=2 https://ip.cloudflare.nyc.mn${IS_CHINESE}) &&
  WAN4=$(awk -F '"' '/"ip"/{print $4}' <<< "$IP4_JSON") &&
  COUNTRY4=$(awk -F '"' '/"country"/{print $4}' <<< "$IP4_JSON") &&
  EMOJI4=$(awk -F '"' '/"emoji"/{print $4}' <<< "$IP4_JSON") &&
  ASNORG4=$(awk -F '"' '/"isp"/{print $4}' <<< "$IP4_JSON")

  local IP6_JSON=$(wget $BIND_ADDRESS6 -6 -qO- --no-check-certificate --tries=2 --timeout=2 https://ip.cloudflare.nyc.mn${IS_CHINESE}) &&
  WAN6=$(awk -F '"' '/"ip"/{print $4}' <<< "$IP6_JSON") &&
  COUNTRY6=$(awk -F '"' '/"country"/{print $4}' <<< "$IP6_JSON") &&
  EMOJI6=$(awk -F '"' '/"emoji"/{print $4}' <<< "$IP6_JSON") &&
  ASNORG6=$(awk -F '"' '/"isp"/{print $4}' <<< "$IP6_JSON")
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
      [ -z "$START_PORT" ] && reading "\n (2/6) $(text 11) " START_PORT
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

  # 选择安装的协议，由于选项 a 为全部协议，所以选项数不是从 a 开始，而是从 b 开始，处理输入：把大写全部变为小写，把不符合的选项去掉，把重复的选项合并
  MAX_CHOOSE_PROTOCOLS=$(asc $[CONSECUTIVE_PORTS+96+1])
  if [ -z "$CHOOSE_PROTOCOLS" ]; then
    hint "\n (1/6) $(text 49) "
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
  if [ "$IS_FAST_INSTALL" = 'is_fast_install' ]; then
    grep -q '^$' <<< "$SERVER_IP" && grep -q '.' <<< "$WAN4" && SERVER_IP=$WAN4
    grep -q '^$' <<< "$SERVER_IP" && grep -q '.' <<< "$WAN6" && SERVER_IP=$WAN6
  fi
  [ -z "$SERVER_IP" ] && reading "\n (4/6) $(text 10) " SERVER_IP
  SERVER_IP=${SERVER_IP:-"$SERVER_IP_DEFAULT"} && WS_SERVER_IP_SHOW=$SERVER_IP
  [ -z "$SERVER_IP" ] && error " $(text 47) "

  # 根据 IPv4 和 IPv6 的网络状态，使不同的 DNS 策略
  [ -x "$(type -p ping)" ] && for i in {1..3}; do
    ping -c 1 -W 1 "151.101.1.91" &>/dev/null && local IS_IPV4=is_ipv4 && break
  done

  if [ -x "$(type -p ping6)" ]; then
    for i in {1..3}; do
      ping6 -c 1 -W 1 "2a04:4e42:200::347" &>/dev/null && local IS_IPV6=is_ipv6 && break
    done
  elif [ -x "$(type -p ping)" ]; then
    for i in {1..3}; do
      ping -c 1 -W 1 "2a04:4e42:200::347" &>/dev/null && local IS_IPV6=is_ipv6 && break
    done
  fi

  case "${IS_IPV4}@${IS_IPV6}" in
    is_ipv4@is_ipv6)
      STRATEGY=prefer_ipv4
      ;;
    is_ipv4@)
      STRATEGY=ipv4_only
      ;;
    @is_ipv6)
      STRATEGY=ipv6_only
      ;;
    *)
      STRATEGY=prefer_ipv4
      ;;
  esac

  # 检测是否解锁 chatGPT
  CHATGPT_OUT=warp-ep;
  [ "$(check_chatgpt $(grep -oE '[46]' <<< "$STRATEGY"))" = 'unlock' ] && CHATGPT_OUT=direct

  # 如果选择有 b j k 这些 reality 协议，自定义 reality 公私钥，如果没有则自动生成
  [ "$NONINTERACTIVE_INSTALL" != 'noninteractive_install' ] && [[ "${INSTALL_PROTOCOLS[@]}" =~ 'b'|'j'|'k' ]] && input_reality_key

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
  [ "$IS_FAST_INSTALL" = 'is_fast_install' ] && UUID_CONFIRM="$UUID_DEFAULT"
  [ -z "$UUID_CONFIRM" ] && reading "\n (5/6) $(text 12) " UUID_CONFIRM
  local UUID_ERROR_TIME=5
  until [[ -z "$UUID_CONFIRM" || "${UUID_CONFIRM,,}" =~ ^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$ ]]; do
    (( UUID_ERROR_TIME-- )) || true
    [ "$UUID_ERROR_TIME" = 0 ] && error "\n $(text 3) \n" || reading "\n $(text 4) \n" UUID_CONFIRM
  done
  UUID_CONFIRM=${UUID_CONFIRM:-"$UUID_DEFAULT"}

  # 输入节点名，以系统的 hostname 作为默认
  local EMOJI="${EMOJI4:-$EMOJI6}"
  local EMOJI="${EMOJI}${EMOJI:+ }"
  if [ -z "$NODE_NAME_CONFIRM" ]; then
    if [ -x "$(type -p hostname)" ]; then
      local NODE_NAME_DEFAULT="${EMOJI}$(hostname)"
    elif [ -s /etc/hostname ]; then
      local NODE_NAME_DEFAULT="${EMOJI}$(cat /etc/hostname)"
    else
      local NODE_NAME_DEFAULT="${EMOJI}Sing-Box"
    fi
    [ "$IS_FAST_INSTALL" = 'is_fast_install' ] && NODE_NAME_CONFIRM="${NODE_NAME_DEFAULT}"
    [ -z "$NODE_NAME_CONFIRM" ] && reading "\n (6/6) $(text 13) " NODE_NAME
    grep -q '^$' <<< "$NODE_NAME" && NODE_NAME_CONFIRM="$NODE_NAME_DEFAULT" || NODE_NAME_CONFIRM="${EMOJI}${NODE_NAME}"
  fi
}

check_dependencies() {
  # 如果是 Alpine，先升级 wget ，安装 systemctl-py 版
  if [ "$SYSTEM" = 'Alpine' ]; then
    local CHECK_WGET=$(wget 2>&1 | sed -n 1p)
    grep -qi 'busybox' <<< "$CHECK_WGET" && ${PACKAGE_INSTALL[int]} wget >/dev/null 2>&1
    local DEPS_CHECK=("bash" "rc-update" "iptables" "ip6tables")
    local DEPS_INSTALL=("bash" "openrc" "iptables" "ip6tables")
    for g in "${!DEPS_CHECK[@]}"; do
      [ ! -x "$(type -p ${DEPS_CHECK[g]})" ] && DEPS_ALPINE+=(${DEPS_INSTALL[g]})
    done
    if [ "${#DEPS_ALPINE[@]}" -ge 1 ]; then
      info "\n $(text 7) $(sed "s/ /,&/g" <<< ${DEPS_ALPINE[@]}) \n"
      ${PACKAGE_UPDATE[int]} >/dev/null 2>&1
      ${PACKAGE_INSTALL[int]} ${DEPS_ALPINE[@]} >/dev/null 2>&1
    fi
  fi

  # 检测 Linux 系统的依赖，升级库并重新安装依赖
  local DEPS_INSTALL=("wget" "tar" "iproute2" "iproute2" "bash" "openssl" "iputils-ping")
  local DEPS_CHECK=("wget" "tar" "ss" "ip" "bash" "openssl" "ping")

  [ "$SYSTEM" != 'Alpine' ] && DEPS_CHECK+=("systemctl") && DEPS_INSTALL+=("systemctl")
  for g in "${!DEPS_CHECK[@]}"; do
    [ ! -x "$(type -p ${DEPS_CHECK[g]})" ] && DEPS+=(${DEPS_INSTALL[g]})
  done

  if [ "$SYSTEM" = 'CentOS' ]; then
    if [ "$IS_CENTOS" = 'CentOS7' ]; then
      yum repolist 2>/dev/null | grep -q epel || DEPS+=(epel-release)
    fi
    [ ! -x "$(type -p firewalld)" ] && DEPS+=(firewalld)
  else
    [ ! -x "$(type -p iptables)" ] && DEPS+=(iptables)
    [ ! -x "$(type -p ip6tables)" ] && DEPS+=(ip6tables)
  fi

  # 先 DEPS 去重，如需要安装的依赖大于0，就更新库并安装
  DEPS=($(echo "${DEPS[@]}" | tr ' ' '\n' | awk '!a[$0]++'))
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

  # 对于 Alpine 系统，确保 OpenRC 服务已启动
  if [ "$SYSTEM" = 'Alpine' ]; then
    if ! rc-service --list | grep -q "^openrc"; then
      rc-update add openrc boot >/dev/null 2>&1
      rc-service openrc start >/dev/null 2>&1
    fi
  fi
}

# 检查并安装 nginx
check_nginx() {
  if [ ! -x "$(type -p nginx)" ]; then
    info "\n $(text 7) nginx \n"
    ${PACKAGE_UPDATE[int]} >/dev/null 2>&1
    ${PACKAGE_INSTALL[int]} nginx >/dev/null 2>&1

    # 如果新安装的 Nginx，使用 cmd_systemctl 停止服务
    cmd_systemctl disable nginx
  fi
}

# Json 生成两个配置文件
export_argo_json_file() {
  local FILE_PATH=$1
  [[ -z "$PORT_NGINX" && -s ${WORK_DIR}/nginx.conf ]] && local PORT_NGINX=$(awk '/listen/{print $2; exit}' ${WORK_DIR}/nginx.conf)
  [ ! -s $FILE_PATH/tunnel.json ] && echo $ARGO_JSON > $FILE_PATH/tunnel.json
  [ ! -s $FILE_PATH/tunnel.yml ] && cat > $FILE_PATH/tunnel.yml << EOF
tunnel: $(awk -F '"' '{print $12}' <<< "$ARGO_JSON")
credentials-file: ${WORK_DIR}/tunnel.json

ingress:
  - hostname: ${ARGO_DOMAIN}
    service: http://localhost:${PORT_NGINX}
  - service: http_status:404
EOF
}

# 生成100年的自签证书，区分使用 IPv4 / IPv6 / 域名
ssl_certificate() {
  mkdir -p ${WORK_DIR}/cert
  openssl ecparam -genkey -name prime256v1 -out ${WORK_DIR}/cert/private.key

  cat > ${WORK_DIR}/cert/cert.conf << EOF
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = $(awk -F . '{print $(NF-1)"."$NF}' <<< "$TLS_SERVER_DEFAULT")

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS = ${TLS_SERVER_DEFAULT}
EOF

  openssl req -new -x509 -days 36500 -key ${WORK_DIR}/cert/private.key -out ${WORK_DIR}/cert/cert.pem -config ${WORK_DIR}/cert/cert.conf -extensions v3_req

  rm -f ${WORK_DIR}/cert/cert.conf
}

# 处理防火墙规则
firewall_configuration() {
  local LISTEN_PORT=$(sed -n "/listen_port/ s#.*:\([0-9]\+\),#\1#gp" /etc/sing-box/conf/*)
  [ -s ${WORK_DIR}/nginx.conf ] && local PORT_NGINX=$(awk '/listen/{print $2; exit}' ${WORK_DIR}/nginx.conf)
  if grep -q "open" <<< "$1"; then
    local LISTEN_PORT_TCP=$(sed -n "s#\([0-9]\+\)#--add-port=\1/tcp#gp" <<< "$LISTEN_PORT")
    local LISTEN_PORT_UDP=$(sed -n "s#\([0-9]\+\)#--add-port=\1/udp#gp" <<< "$LISTEN_PORT")
    firewall-cmd --zone=public --add-port=${PORT_NGINX}/tcp --permanent >/dev/null 2>&1
  elif grep -q "close" <<< "$1"; then
    local LISTEN_PORT_TCP=$(sed -n "s#\([0-9]\+\)#--remove-port=\1/tcp#gp" <<< "$LISTEN_PORT")
    local LISTEN_PORT_UDP=$(sed -n "s#\([0-9]\+\)#--remove-port=\1/udp#gp" <<< "$LISTEN_PORT")
    firewall-cmd --zone=public --remove-port=${PORT_NGINX}/tcp --permanent >/dev/null 2>&1
  fi
  firewall-cmd --zone=public ${LISTEN_PORT_TCP} --permanent >/dev/null 2>&1
  firewall-cmd --zone=public ${LISTEN_PORT_UDP} --permanent >/dev/null 2>&1
  firewall-cmd --reload >/dev/null 2>&1

  if [[ -s /etc/selinux/config && -x "$(type -p getenforce)" && $(getenforce) = 'Enforcing' ]]; then
    hint "\n $(text 84) "
    setenforce 0
    grep -qs '^SELINUX=disabled$' /etc/selinux/config || sed -i 's/^SELINUX=[epd].*/# &/; /SELINUX=[epd]/a\SELINUX=disabled' /etc/selinux/config
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
    ~*Neko|Throne              /neko;           # 匹配 Neko / Throne 客户端
    ~*ShadowRocket             /shadowrocket;   # 匹配 ShadowRocket 客户端
    ~*SFM|SFI|SFA              /sing-box;       # 匹配 Sing-box 官方客户端
#   ~*Chrome|Firefox|Mozilla   /;               # 添加更多的分流规则
  }
  map \$http_user_agent \$path2 {
    default                    /;               # 默认路径
    ~*v2rayN                   /v2rayn;         # 匹配 V2rayN 客户端
    ~*clash                    /clash2;         # 匹配 Clash 客户端
    ~*Neko|Throne              /neko;           # 匹配 Neko 客户端
    ~*ShadowRocket             /shadowrocket;   # 匹配 ShadowRocket 客户端
    ~*SFM|SFI|SFA              /sing-box;       # 匹配 Sing-box 官方客户端
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
    server_name localhost;
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

  echo "$NGINX_CONF" > ${WORK_DIR}/nginx.conf
}

# 生成 sing-box 配置文件
sing-box_json() {
  local IS_CHANGE=$1
  mkdir -p ${WORK_DIR}/conf ${WORK_DIR}/logs ${WORK_DIR}/subscribe

  # 判断是否为新安装，不为 change 就是新安装
  if [ "$IS_CHANGE" = 'change' ]; then
    # 判断 sing-box 主程序所在路径
    DIR=${WORK_DIR}
  else
    DIR=$TEMP_DIR

    # 生成 log 配置
    cat > ${WORK_DIR}/conf/00_log.json << EOF
{
    "log":{
        "disabled":false,
        "level":"error",
        "output":"${WORK_DIR}/logs/box.log",
        "timestamp":true
    }
}
EOF

    # 生成 outbound 配置
    cat > ${WORK_DIR}/conf/01_outbounds.json << EOF
{
    "outbounds":[
        {
            "type":"direct",
            "tag":"direct"
        }
    ]
}
EOF

    # 生成 endpoint 配置
    cat > ${WORK_DIR}/conf/02_endpoints.json << EOF
{
    "endpoints":[
        {
            "type":"wireguard",
            "tag":"warp-ep",
            "mtu":1280,
            "address":[
                "172.16.0.2/32",
                "2606:4700:110:8a36:df92:102a:9602:fa18/128"
            ],
            "private_key":"YFYOAdbw1bKTHlNNi+aEjBM3BO7unuFC5rOkMRAz9XY=",
            "peers": [
              {
                "address": "engage.cloudflareclient.com",
                "port":2408,
                "public_key":"bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=",
                "allowed_ips": [
                  "0.0.0.0/0",
                  "::/0"
                ],
                "reserved":[
                    78,
                    135,
                    76
                ]
              }
            ]
        }
    ]
}
EOF

    # 生成 route 配置
    cat > ${WORK_DIR}/conf/03_route.json << EOF
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
                "action": "sniff"
            },
            {
                "action": "resolve",
                "domain":[
                    "api.openai.com"
                ],
                "strategy": "prefer_ipv4"
            },
            {
                "action": "resolve",
                "rule_set":[
                    "geosite-openai"
                ],
                "strategy": "prefer_ipv6"
            },
            {
                "domain":[
                    "api.openai.com"
                ],
                "rule_set":[
                    "geosite-openai"
                ],
                "outbound":"${CHATGPT_OUT}"
            }
        ]
    }
}
EOF

    # 生成缓存文件
    cat > ${WORK_DIR}/conf/04_experimental.json << EOF
{
    "experimental": {
        "cache_file": {
            "enabled": true,
            "path": "${WORK_DIR}/cache.db"
        }
    }
}
EOF

    # 生成 dns 配置文件
    cat > ${WORK_DIR}/conf/05_dns.json << EOF
{
    "dns":{
        "servers":[
            {
                "type":"local"
            }
        ],
        "strategy": "${STRATEGY}"
    }
}
EOF

    # 内建的 NTP 客户端服务配置文件，这对于无法进行时间同步的环境很有用
    cat > ${WORK_DIR}/conf/06_ntp.json << EOF
{
    "ntp": {
        "enabled": true,
        "server": "time.apple.com",
        "server_port": 123,
        "interval": "60m"
    }
}
EOF
  fi

  # 生成 Reality 公私钥，第一次安装的时候，如有指定的私钥，则使用该私钥及生成对应的公钥；如没有指定私钥则使用新生成的；添加协议的时，使用相应数组里的第一个非空值，如全空则像第一次安装那样使用新生成的
  generate_reality_keypair() {
    [ "$1" = 'convert_error' ] && hint " $(text 116) "
    REALITY_KEYPAIR=$($DIR/sing-box generate reality-keypair) && REALITY_PRIVATE=$(awk '/PrivateKey/{print $NF}' <<< "$REALITY_KEYPAIR") && REALITY_PUBLIC=$(awk '/PublicKey/{print $NF}' <<< "$REALITY_KEYPAIR")
  }

  if [[ "${#REALITY_PRIVATE}" = 43 && "${#REALITY_PUBLIC}" = 0 ]]; then
    if [ "$(type -p xxd)" ]; then
      until [ -n "$REALITY_PUBLIC" ]; do
        # convert base64url -> base64 (standard), add padding
        local B64=$(printf '%s' "$REALITY_PRIVATE" | tr '_-' '/+')
        local MOD=$(( ${#B64} % 4 ))
        if [ $MOD -eq 2 ]; then
          B64="${B64}=="
        elif [ $MOD -eq 3 ]; then
          B64="${B64}="
        elif [ $MOD -eq 1 ]; then
          generate_reality_keypair convert_error
          continue
        fi

        # decode to raw 32 bytes
        echo "$B64" | base64 -d > $TEMP_DIR/_X25519_PRIV_RAW || { generate_reality_keypair convert_error; continue; }

        local PRIV_LEN=$(stat -c%s $TEMP_DIR/_X25519_PRIV_RAW 2>/dev/null || stat -f%z $TEMP_DIR/_X25519_PRIV_RAW)
        [ "$PRIV_LEN" -ne 32 ] && { generate_reality_keypair convert_error; continue; }

        # DER prefix for PKCS#8 private key with OID 1.3.101.110 (X25519)
        # Hex: 30 2e 02 01 00 30 05 06 03 2b 65 6e 04 22 04 20
        local PREFIX_HEX="302e020100300506032b656e04220420"

        # append raw private key hex and create DER
        local PRIV_HEX=$(xxd -p -c 256 $TEMP_DIR/_X25519_PRIV_RAW | tr -d '\n')
        printf "%s%s" "$PREFIX_HEX" "$PRIV_HEX" | xxd -r -p > $TEMP_DIR/_X25519_PRIV_DER

        # convert DER PKCS8 -> PEM private key
        openssl pkcs8 -inform DER -in $TEMP_DIR/_X25519_PRIV_DER -nocrypt -out $TEMP_DIR/_X25519_PRIV_PEM 2>/dev/null

        # extract public key in DER
        openssl pkey -in $TEMP_DIR/_X25519_PRIV_PEM -pubout -outform DER > $TEMP_DIR/_X25519_PUB_DER 2>/dev/null

        # last 32 bytes are the raw public key
        tail -c 32 $TEMP_DIR/_X25519_PUB_DER > $TEMP_DIR/_X25519_PUB_RAW

        # encode to base64url (no padding)
        REALITY_PUBLIC=$(base64 -w0 $TEMP_DIR/_X25519_PUB_RAW | tr '+/' '-_' | sed -E 's/=+$//')
      done
    else
      REALITY_PUBLIC=$(wget --no-check-certificate -qO- --tries=3 --timeout=2 https://realitykey.cloudflare.now.cc/?privateKey=$REALITY_PRIVATE | awk -F '"' '/publicKey/{print $4}')
    fi
  elif [[ "${#REALITY_PRIVATE[@]}" = 0 && "${#REALITY_PUBLIC[@]}" = 0 ]]; then
    generate_reality_keypair new_keypair
  else
    REALITY_PRIVATE=$(awk '{print $1}' <<< "${REALITY_PRIVATE[@]}") && REALITY_PUBLIC=$(awk '{print $1}' <<< "${REALITY_PUBLIC[@]}")
  fi

  # 生成 TLS 网站
  [ "${#TLS_SERVER[@]}" -gt 0 ] && TLS_SERVER=$(awk '{print $1}' <<< "${TLS_SERVER[@]}") || TLS_SERVER=$TLS_SERVER_DEFAULT

  # 第1个协议为 b  (a为全部)，生成 XTLS + Reality 配置
  CHECK_PROTOCOLS=b
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    [ -z "$PORT_XTLS_REALITY" ] && PORT_XTLS_REALITY=$[START_PORT+$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")]
    NODE_NAME[11]=${NODE_NAME[11]:-"$NODE_NAME_CONFIRM"} && UUID[11]=${UUID[11]:-"$UUID_CONFIRM"} && TLS_SERVER[11]=${TLS_SERVER[11]:-"$TLS_SERVER"} && REALITY_PRIVATE[11]=${REALITY_PRIVATE[11]:-"$REALITY_PRIVATE"} && REALITY_PUBLIC[11]=${REALITY_PUBLIC[11]:-"$REALITY_PUBLIC"} &&
    cat > ${WORK_DIR}/conf/11_${NODE_TAG[0]}_inbounds.json << EOF
//  "public_key":"${REALITY_PUBLIC[11]}"
{
    "inbounds":[
        {
            "type":"vless",
            "tag":"${NODE_NAME[11]} ${NODE_TAG[0]}",
            "listen":"::",
            "listen_port":$PORT_XTLS_REALITY,
            "users":[
                {
                    "uuid":"${UUID[11]}",
                    "flow":"xtls-rprx-vision"
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
                "enabled":false,
                "padding":false,
                "brutal":{
                    "enabled":false,
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
    cat > ${WORK_DIR}/conf/12_${NODE_TAG[1]}_inbounds.json << EOF
{
    "inbounds":[
        {
            "type":"hysteria2",
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
                "alpn":[
                    "h3"
                ],
                "min_version":"1.3",
                "max_version":"1.3",
                "certificate_path":"${WORK_DIR}/cert/cert.pem",
                "key_path":"${WORK_DIR}/cert/private.key"
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
    cat > ${WORK_DIR}/conf/13_${NODE_TAG[2]}_inbounds.json << EOF
{
    "inbounds":[
        {
            "type":"tuic",
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
                "certificate_path":"${WORK_DIR}/cert/cert.pem",
                "key_path":"${WORK_DIR}/cert/private.key"
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

    cat > ${WORK_DIR}/conf/14_${NODE_TAG[3]}_inbounds.json << EOF
{
    "inbounds":[
        {
            "type":"shadowtls",
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
                    "enabled":${IS_BRUTAL},
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
    cat > ${WORK_DIR}/conf/15_${NODE_TAG[4]}_inbounds.json << EOF
{
    "inbounds":[
        {
            "type":"shadowsocks",
            "tag":"${NODE_NAME[15]} ${NODE_TAG[4]}",
            "listen":"::",
            "listen_port":$PORT_SHADOWSOCKS,
            "method":"${SHADOWSOCKS_METHOD}",
            "password":"${UUID[15]}",
            "multiplex":{
                "enabled":true,
                "padding":true,
                "brutal":{
                    "enabled":${IS_BRUTAL},
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
    cat > ${WORK_DIR}/conf/16_${NODE_TAG[5]}_inbounds.json << EOF
{
    "inbounds":[
        {
            "type":"trojan",
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
                "certificate_path":"${WORK_DIR}/cert/cert.pem",
                "key_path":"${WORK_DIR}/cert/private.key"
            },
            "multiplex":{
                "enabled":true,
                "padding":true,
                "brutal":{
                    "enabled":${IS_BRUTAL},
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
    cat > ${WORK_DIR}/conf/17_${NODE_TAG[6]}_inbounds.json << EOF
//  "WS_SERVER_IP_SHOW": "${WS_SERVER_IP[17]}"
//  "VMESS_HOST_DOMAIN": "${VMESS_HOST_DOMAIN}${ARGO_DOMAIN}"
//  "CDN": "${CDN[17]}"
{
    "inbounds":[
        {
            "type":"vmess",
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
                "max_early_data":2560,
                "early_data_header_name":"Sec-WebSocket-Protocol"
            },
            "multiplex":{
                "enabled":true,
                "padding":true,
                "brutal":{
                    "enabled":${IS_BRUTAL},
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
    cat > ${WORK_DIR}/conf/18_${NODE_TAG[7]}_inbounds.json << EOF
//  "WS_SERVER_IP_SHOW": "${WS_SERVER_IP[18]}"
//  "CDN": "${CDN[18]}"
{
    "inbounds":[
        {
            "type":"vless",
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
                "max_early_data":2560,
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
                    "enabled":${IS_BRUTAL},
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
    cat > ${WORK_DIR}/conf/19_${NODE_TAG[8]}_inbounds.json << EOF
//  "public_key":"${REALITY_PUBLIC[19]}"
{
    "inbounds":[
        {
            "type":"vless",
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
            "transport":{
                "type": "http"
            },
            "multiplex":{
                "enabled":true,
                "padding":true,
                "brutal":{
                    "enabled":${IS_BRUTAL},
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
    cat > ${WORK_DIR}/conf/20_${NODE_TAG[9]}_inbounds.json << EOF
//  "public_key":"${REALITY_PUBLIC[20]}"
{
    "inbounds":[
        {
            "type":"vless",
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
            "transport":{
                "type": "grpc",
                "service_name": "grpc"
            },
            "multiplex":{
                "enabled":true,
                "padding":true,
                "brutal":{
                    "enabled":${IS_BRUTAL},
                    "up_mbps":1000,
                    "down_mbps":1000
                }
            }
        }
    ]
}
EOF
  fi

  # 生成 anytls 配置
  CHECK_PROTOCOLS=$(asc "$CHECK_PROTOCOLS" ++)
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    [ -z "$PORT_ANYTLS" ] && PORT_ANYTLS=$[START_PORT+$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")]
    NODE_NAME[21]=${NODE_NAME[21]:-"$NODE_NAME_CONFIRM"} && UUID[21]=${UUID[21]:-"$UUID_CONFIRM"}

    cat > ${WORK_DIR}/conf/21_${NODE_TAG[10]}_inbounds.json << EOF
{
    "inbounds":[
        {
            "type":"anytls",
            "tag":"${NODE_NAME[21]} anytls",
            "listen":"::",
            "listen_port":$PORT_ANYTLS,
            "users":[
                {
                    "password":"${UUID[21]}"
                }
            ],
            "padding_scheme":[],
            "tls":{
                "enabled":true,
                "certificate_path":"${WORK_DIR}/cert/cert.pem",
                "key_path":"${WORK_DIR}/cert/private.key"
            }
        }
    ]
}
EOF
  fi
}

# Sing-box 生成守护进程文件
sing-box_systemd() {
  if [ "$SYSTEM" = 'Alpine' ]; then
    local OPENRC_SERVICE="#!/sbin/openrc-run

name=\"sing-box\"
description=\"sing-box service\"
command=\"${WORK_DIR}/sing-box\"
command_args=\"run -C ${WORK_DIR}/conf\"
pidfile=\"/var/run/\${RC_SVCNAME}.pid\"
command_background=\"yes\"
output_log=\"${WORK_DIR}/logs/sing-box.log\"
error_log=\"${WORK_DIR}/logs/sing-box.log\"

depend() {
    need net
    after net"

    # 如果配置了 Nginx，添加依赖
    [ -n "$PORT_NGINX" ] && OPENRC_SERVICE+="
    need nginx"

    # 添加 start_pre 函数，确保目录存在并设置正确权限
    OPENRC_SERVICE+="
}

start_pre() {
    # 确保日志目录和PID目录存在并有正确权限
    mkdir -p ${WORK_DIR}/logs
    mkdir -p /var/run
    chmod 755 /var/run"

    # 如果配置了 Nginx，启动 Nginx
    [ -n "$PORT_NGINX" ] && OPENRC_SERVICE+="
    $(type -p nginx) -c ${WORK_DIR}/nginx.conf"

    OPENRC_SERVICE+="
    # 确保 PID 文件不存在，避免启动失败
    rm -f \$pidfile
}"

    # 添加 stop_post 函数，用于在服务停止后清理 nginx 进程
    [ -n "$PORT_NGINX" ] && OPENRC_SERVICE+="

stop_post() {
    # 停止 nginx：优先用内置命令
    if command -v /usr/sbin/nginx >/dev/null 2>&1; then
        /usr/sbin/nginx -s quit -c ${WORK_DIR}/nginx.conf 2>/dev/null
        sleep 1 # 等待优雅关闭
        # 如果仍运行，用 SIGKILL
        local NGINX_MASTER=\$(pgrep -f \"nginx: master process /usr/sbin/nginx -c ${WORK_DIR}/nginx.conf\")
        if [ -n \"\$NGINX_MASTER\" ]; then
            kill -KILL \$NGINX_MASTER 2>/dev/null
        fi
    fi
}

stop() {
    ebegin \"Stopping \${RC_SVCNAME}\"
    # 先停止主进程（OpenRC 会调用）
    start-stop-daemon --stop --pidfile \$pidfile --retry 5
    eend \$? \"Failed to stop \${RC_SVCNAME}\"

    # 然后运行 post 清理
    stop_post
}"

    echo "$OPENRC_SERVICE" > ${SINGBOX_DAEMON_FILE}
    chmod +x ${SINGBOX_DAEMON_FILE}
  else
    # 原有的 systemd 服务创建代码
    SING_BOX_SERVICE="[Unit]
Description=sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

[Service]
User=root
Type=simple
NoNewPrivileges=yes
TimeoutStartSec=0
WorkingDirectory=${WORK_DIR}
"
    [[ -n "$PORT_NGINX" && "$IS_CENTOS" != 'CentOS7' ]] && SING_BOX_SERVICE+="ExecStartPre=$(type -p nginx) -c ${WORK_DIR}/nginx.conf
"
    SING_BOX_SERVICE+="ExecStart=${WORK_DIR}/sing-box run -C ${WORK_DIR}/conf
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target"

    echo "$SING_BOX_SERVICE" > ${SINGBOX_DAEMON_FILE}
    systemctl daemon-reload
  fi
}

# Argo 生成守护进程文件
argo_systemd() {
  if [ "$SYSTEM" = 'Alpine' ]; then
    # 分离命令和参数
    local COMMAND="${ARGO_RUNS%% --*}"   # 提取命令部分（包括 cloudflared tunnel）
    local ARGS="${ARGO_RUNS#$COMMAND }"  # 提取参数部分

    cat > ${ARGO_DAEMON_FILE} << EOF
#!/sbin/openrc-run

name="argo"
description="Cloudflare Tunnel service"
command="${COMMAND}"
command_args="${ARGS}"
pidfile="/var/run/\${RC_SVCNAME}.pid"
command_background="yes"
output_log="${WORK_DIR}/logs/argo.log"
error_log="${WORK_DIR}/logs/argo.log"

depend() {
    need net
    after net
}

start_pre() {
    # 确保日志目录和PID目录存在并有正确权限
    mkdir -p ${WORK_DIR}/logs
    mkdir -p /var/run
    chmod 755 /var/run

    # 确保 PID 文件不存在，避免启动失败
    rm -f \$pidfile
}
EOF
    chmod +x ${ARGO_DAEMON_FILE}
  else
    # 原有的 systemd 服务创建代码
    cat > ${ARGO_DAEMON_FILE} << EOF
[Unit]
Description=Cloudflare Tunnel
After=network.target

[Service]
Type=simple
WorkingDirectory=$WORK_DIR
NoNewPrivileges=yes
TimeoutStartSec=0
ExecStart=${ARGO_RUNS}
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
  fi
}

# 获取原有各协议的参数，先清空所有的 key-value
fetch_nodes_value() {
  unset NODE_NAME PORT_XTLS_REALITY UUID TLS_SERVER REALITY_PRIVATE REALITY_PUBLIC PORT_HYSTERIA2 PORT_TUIC TUIC_PASSWORD TUIC_CONGESTION_CONTROL PORT_SHADOWTLS SHADOWTLS_PASSWORD SHADOWSOCKS_METHOD PORT_SHADOWSOCKS PORT_TROJAN TROJAN_PASSWORD PORT_VMESS_WS VMESS_WS_PATH WS_SERVER_IP WS_SERVER_IP_SHOW VMESS_HOST_DOMAIN CDN PORT_VLESS_WS VLESS_WS_PATH VLESS_HOST_DOMAIN PORT_H2_REALITY PORT_GRPC_REALITY ARGO_DOMAIN PORT_ANYTLS SELF_SIGNED_FINGERPRINT_SHA256 SELF_SIGNED_FINGERPRINT_BASE64

  # 获取公共数据
  ls ${WORK_DIR}/conf/*-ws*inbounds.json >/dev/null 2>&1 && SERVER_IP=$(awk -F '"' '/"WS_SERVER_IP_SHOW"/{print $4; exit}' ${WORK_DIR}/conf/*-ws*inbounds.json) || SERVER_IP=$(grep -A1 '"tag"' ${WORK_DIR}/list | sed -E '/-ws(-tls)*",$/{N;d}' | awk -F '"' '/"server"/{count++; if (count == 1) {print $4; exit}}')
  EXISTED_PORTS=$(awk -F ':|,' '/listen_port/{print $2}' ${WORK_DIR}/conf/*_inbounds.json)
  START_PORT=$(awk 'NR == 1 { min = $0 } { if ($0 < min) min = $0; count++ } END {print min}' <<< "$EXISTED_PORTS")
  [[ -z "$NODE_NAME_CONFIRM" && -s ${WORK_DIR}/subscribe/clash ]] && NODE_NAME_CONFIRM=$(awk -F "'" '/u: &u/{print $2; exit}' ${WORK_DIR}/subscribe/clash)

  # 如有 Argo，获取 Argo Tunnel
  [[ ${STATUS[1]} =~ $(text 27)|$(text 28) ]] && grep -q '\--url' ${ARGO_DAEMON_FILE} && { cmd_systemctl enable argo; sleep 2 && cmd_systemctl status argo &>/dev/null && fetch_quicktunnel_domain; }

  # 获取 Nginx 端口和路径
  [[ "${IS_SUB}" = 'is_sub' || "${IS_ARGO}" = 'is_argo' ]] && local NGINX_JSON=$(cat ${WORK_DIR}/nginx.conf) &&
  PORT_NGINX=$(awk '/listen/{print $2; exit}' <<< "$NGINX_JSON") &&
  UUID_CONFIRM=$(grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' <<< "$NGINX_JSON" | sed -n '1p')

  # 获取 XTLS + Reality key-value
  [ -s ${WORK_DIR}/conf/*_${NODE_TAG[0]}_inbounds.json ] && local JSON=$(cat ${WORK_DIR}/conf/*_${NODE_TAG[0]}_inbounds.json) && NODE_NAME[11]=$(sed -n "s/.*\"tag\":\"\(.*\) ${NODE_TAG[0]}.*/\1/p" <<< "$JSON") && PORT_XTLS_REALITY=$(sed -n 's/.*"listen_port":\([0-9]\+\),/\1/gp' <<< "$JSON") && UUID[11]=$(awk -F '"' '/"uuid"/{print $4}' <<< "$JSON") && TLS_SERVER[11]=$(awk -F '"' '/"server_name"/{print $4}' <<< "$JSON") && REALITY_PRIVATE[11]=$(awk -F '"' '/"private_key"/{print $4}' <<< "$JSON") && REALITY_PUBLIC[11]=$(awk -F '"' '/"public_key"/{print $4}' <<< "$JSON")

  # 获取 Hysteria2 key-value
  [ -s ${WORK_DIR}/conf/*_${NODE_TAG[1]}_inbounds.json ] && local JSON=$(cat ${WORK_DIR}/conf/*_${NODE_TAG[1]}_inbounds.json) && NODE_NAME[12]=$(sed -n "s/.*\"tag\":\"\(.*\) ${NODE_TAG[1]}.*/\1/p" <<< "$JSON") && PORT_HYSTERIA2=$(sed -n 's/.*"listen_port":\([0-9]\+\),/\1/gp' <<< "$JSON") && UUID[12]=$(awk -F '"' '/"password"/{count++; if (count == 1) {print $4; exit}}' <<< "$JSON") && check_port_hopping_nat

  # 获取 Tuic V5 key-value
  [ -s ${WORK_DIR}/conf/*_${NODE_TAG[2]}_inbounds.json ] && local JSON=$(cat ${WORK_DIR}/conf/*_${NODE_TAG[2]}_inbounds.json) && NODE_NAME[13]=$(sed -n "s/.*\"tag\":\"\(.*\) ${NODE_TAG[2]}.*/\1/p" <<< "$JSON") && PORT_TUIC=$(sed -n 's/.*"listen_port":\([0-9]\+\),/\1/gp' <<< "$JSON") && UUID[13]=$(awk -F '"' '/"uuid"/{print $4}' <<< "$JSON") && TUIC_PASSWORD=$(awk -F '"' '/"password"/{print $4}' <<< "$JSON") && TUIC_CONGESTION_CONTROL=$(awk -F '"' '/"congestion_control"/{print $4}' <<< "$JSON")

  # 获取 ShadowTLS key-value
  [ -s ${WORK_DIR}/conf/*_${NODE_TAG[3]}_inbounds.json ] && local JSON=$(cat ${WORK_DIR}/conf/*_${NODE_TAG[3]}_inbounds.json) && NODE_NAME[14]=$(sed -n "s/.*\"tag\":\"\(.*\) ${NODE_TAG[3]}.*/\1/p" <<< "$JSON") && PORT_SHADOWTLS=$(sed -n 's/.*"listen_port":\([0-9]\+\),/\1/gp' <<< "$JSON") && UUID[14]=$(awk -F '"' '/"password"/{count++; if (count == 1) {print $4; exit}}' <<< "$JSON") && SHADOWTLS_PASSWORD=$(awk -F '"' '/"password"/{count++; if (count == 2) {print $4; exit}}' <<< "$JSON") && TLS_SERVER[14]=$(awk -F '"' '/"server"/{print $4}' <<< "$JSON") && SHADOWTLS_METHOD=$(awk -F '"' '/"method"/{print $4}' <<< "$JSON")

  # 获取 Shadowsocks key-value
  [ -s ${WORK_DIR}/conf/*_${NODE_TAG[4]}_inbounds.json ] && local JSON=$(cat ${WORK_DIR}/conf/*_${NODE_TAG[4]}_inbounds.json) && NODE_NAME[15]=$(sed -n "s/.*\"tag\":\"\(.*\) ${NODE_TAG[4]}.*/\1/p" <<< "$JSON") && PORT_SHADOWSOCKS=$(sed -n 's/.*"listen_port":\([0-9]\+\),/\1/gp' <<< "$JSON") && UUID[15]=$(awk -F '"' '/"password"/{print $4}' <<< "$JSON") && SHADOWSOCKS_METHOD=$(awk -F '"' '/"method"/{print $4}' <<< "$JSON")

  # 获取 Trojan key-value
  [ -s ${WORK_DIR}/conf/*_${NODE_TAG[5]}_inbounds.json ] && local JSON=$(cat ${WORK_DIR}/conf/*_${NODE_TAG[5]}_inbounds.json) && NODE_NAME[16]=$(sed -n "s/.*\"tag\":\"\(.*\) ${NODE_TAG[5]}.*/\1/p" <<< "$JSON") && PORT_TROJAN=$(sed -n 's/.*"listen_port":\([0-9]\+\),/\1/gp' <<< "$JSON") && TROJAN_PASSWORD=$(awk -F '"' '/"password"/{print $4}' <<< "$JSON")

  # 获取 vmess + ws key-value
  [ -s ${WORK_DIR}/conf/*_${NODE_TAG[6]}_inbounds.json ] && local JSON=$(cat ${WORK_DIR}/conf/*_${NODE_TAG[6]}_inbounds.json) && NODE_NAME[17]=$(sed -n "s/.*\"tag\":\"\(.*\) ${NODE_TAG[6]}.*/\1/p" <<< "$JSON") && PORT_VMESS_WS=$(sed -n 's/.*"listen_port":\([0-9]\+\),/\1/gp' <<< "$JSON") && UUID[17]=$(awk -F '"' '/"uuid"/{print $4}' <<< "$JSON") && VMESS_WS_PATH=$(sed -n 's#.*"path":"/\(.*\)",#\1#p' <<< "$JSON") && WS_SERVER_IP[17]=$(awk  -F '"' '/"WS_SERVER_IP_SHOW"/{print $4}' <<< "$JSON") && CDN[17]=$(awk  -F '"' '/"CDN"/{print $4}' <<< "$JSON") && [[ "${STATUS[1]}" =~ $(text 27)|$(text 28) ]] && ARGO_DOMAIN=$(awk  -F '"' '/"VMESS_HOST_DOMAIN"/{print $4}' <<< "$JSON") || VMESS_HOST_DOMAIN=$(awk  -F '"' '/"VMESS_HOST_DOMAIN"/{print $4}' <<< "$JSON")

  # 获取 vless + ws + tls key-value
  [ -s ${WORK_DIR}/conf/*_${NODE_TAG[7]}_inbounds.json ] && local JSON=$(cat ${WORK_DIR}/conf/*_${NODE_TAG[7]}_inbounds.json) && NODE_NAME[18]=$(sed -n "s/.*\"tag\":\"\(.*\) ${NODE_TAG[7]}.*/\1/p" <<< "$JSON") && PORT_VLESS_WS=$(sed -n 's/.*"listen_port":\([0-9]\+\),/\1/gp' <<< "$JSON") && UUID[18]=$(awk -F '"' '/"uuid"/{print $4}' <<< "$JSON") && VLESS_WS_PATH=$(sed -n 's#.*"path":"/\(.*\)",#\1#p' <<< "$JSON") && WS_SERVER_IP[18]=$(awk  -F '"' '/"WS_SERVER_IP_SHOW"/{print $4}' <<< "$JSON") && CDN[18]=$(awk  -F '"' '/"CDN"/{print $4}' <<< "$JSON") && [[ "${STATUS[1]}" =~ $(text 27)|$(text 28) ]] && ARGO_DOMAIN=$(awk -F '"' '/"server_name"/{print $4}' <<< "$JSON") || VLESS_HOST_DOMAIN=$(awk -F '"' '/"server_name"/{print $4}' <<< "$JSON")

  # 获取 H2 + Reality key-value
  [ -s ${WORK_DIR}/conf/*_${NODE_TAG[8]}_inbounds.json ] && local JSON=$(cat ${WORK_DIR}/conf/*_${NODE_TAG[8]}_inbounds.json) && NODE_NAME[19]=$(sed -n "s/.*\"tag\":\"\(.*\) ${NODE_TAG[8]}.*/\1/p" <<< "$JSON") && PORT_H2_REALITY=$(sed -n 's/.*"listen_port":\([0-9]\+\),/\1/gp' <<< "$JSON") && UUID[19]=$(awk -F '"' '/"uuid"/{print $4}' <<< "$JSON") && TLS_SERVER[19]=$(awk -F '"' '/"server"/{print $4}' <<< "$JSON") && REALITY_PRIVATE[19]=$(awk -F '"' '/"private_key"/{print $4}' <<< "$JSON") && REALITY_PUBLIC[19]=$(awk -F '"' '/"public_key"/{print $4}' <<< "$JSON")

  # 获取 gRPC + Reality key-value
  [ -s ${WORK_DIR}/conf/*_${NODE_TAG[9]}_inbounds.json ] && local JSON=$(cat ${WORK_DIR}/conf/*_${NODE_TAG[9]}_inbounds.json) && NODE_NAME[20]=$(sed -n "s/.*\"tag\":\"\(.*\) ${NODE_TAG[9]}.*/\1/p" <<< "$JSON") && PORT_GRPC_REALITY=$(sed -n 's/.*"listen_port":\([0-9]\+\),/\1/gp' <<< "$JSON") && UUID[20]=$(awk -F '"' '/"uuid"/{print $4}' <<< "$JSON") && TLS_SERVER[20]=$(awk -F '"' '/"server"/{print $4}' <<< "$JSON") && REALITY_PRIVATE[20]=$(awk -F '"' '/"private_key"/{print $4}' <<< "$JSON") && REALITY_PUBLIC[20]=$(awk -F '"' '/"public_key"/{print $4}' <<< "$JSON")

  # 获取 anytls key-value
  [ -s ${WORK_DIR}/conf/*_${NODE_TAG[10]}_inbounds.json ] && local JSON=$(cat ${WORK_DIR}/conf/*_${NODE_TAG[10]}_inbounds.json) && NODE_NAME[21]=$(sed -n "s/.*\"tag\":\"\(.*\) ${NODE_TAG[10]}.*/\1/p" <<< "$JSON") && PORT_ANYTLS=$(sed -n 's/.*"listen_port":\([0-9]\+\),/\1/gp' <<< "$JSON") && UUID[21]=$(awk -F '"' '/"password"/{print $4}' <<< "$JSON")
}

# 获取 Argo 临时隧道域名
fetch_quicktunnel_domain() {
  unset CLOUDFLARED_PID METRICS_ADDRESS ARGO_DOMAIN
  local QUICKTUNNEL_ERROR_TIME=20
  until [ -n "$ARGO_DOMAIN" ]; do
    local CLOUDFLARED_PID=$(ps -eo pid,args | awk -v work_dir="$WORK_DIR" '$0~(work_dir"/cloudflared"){print $1;exit}')
    [[ -z "$METRICS_ADDRESS" && "$CLOUDFLARED_PID" =~ ^[0-9]+$ ]] && local METRICS_ADDRESS=$(ss -nltp | grep "pid=$CLOUDFLARED_PID" | awk '{print $4}')
    [ -n "$METRICS_ADDRESS" ] && ARGO_DOMAIN=$(wget -qO- http://$METRICS_ADDRESS/quicktunnel | awk -F '"' '{print $4}')
    [[ ! "$ARGO_DOMAIN" =~ trycloudflare\.com$ ]] && (( QUICKTUNNEL_ERROR_TIME-- )) && sleep 2 || break
    [ "$QUICKTUNNEL_ERROR_TIME" = '0' ] && error " $(text 93) "
  done

  # 把临时隧道写到 Sing-box 相应的 ws inbounds 文件
  [ -s ${WORK_DIR}/conf/17_${NODE_TAG[6]}_inbounds.json ] && sed -i "s/VMESS_HOST_DOMAIN.*/VMESS_HOST_DOMAIN\": \"$ARGO_DOMAIN\"/" ${WORK_DIR}/conf/17_${NODE_TAG[6]}_inbounds.json
  [ -s ${WORK_DIR}/conf/18_${NODE_TAG[7]}_inbounds.json ] && sed -i "s/\"server_name\":.*/\"server_name\": \"$ARGO_DOMAIN\",/" ${WORK_DIR}/conf/18_${NODE_TAG[7]}_inbounds.json
}

# 安装 sing-box 全家桶
install_sing-box() {
  sing-box_variables
  [ -n "$PORT_NGINX" ] && check_nginx
  [ ! -d ${WORK_DIR}/logs ] && mkdir -p ${WORK_DIR}/logs
  [ ! -d ${TEMP_DIR} ] && mkdir -p $TEMP_DIR
  ssl_certificate
  hint "\n $(text 2) " && wait
  sing-box_json
  echo "${L^^}" > ${WORK_DIR}/language
  cp $TEMP_DIR/sing-box $TEMP_DIR/jq ${WORK_DIR}
  [ -x $TEMP_DIR/qrencode ] && cp $TEMP_DIR/qrencode ${WORK_DIR}

  # 生成 sing-box systemd 配置文件
  sing-box_systemd

  # 生成 Argo systemd 配置文件，并复制 cloudflared 可执行二进制文件
  cp $TEMP_DIR/cloudflared ${WORK_DIR}
  [ -n "$ARGO_RUNS" ] && argo_systemd

  # 如果是 Json Argo，把配置文件复制到工作目录
  [ -n "$ARGO_JSON" ] && cp $TEMP_DIR/tunnel.* ${WORK_DIR}

  # 生成 Nginx 配置文件
  [ -n "$PORT_NGINX" ] && export_nginx_conf_file

  # 系统启动 sing-box 服务
  cmd_systemctl enable sing-box

  # 等待服务启动
  sleep 2

  # 处理防火墙相关端口
  [ "$SYSTEM" = 'CentOS' ] && firewall_configuration open

  # 检查服务是否成功启动
  if cmd_systemctl status sing-box &>/dev/null; then
    STATUS[0]=$(text 28)
    info "\n Sing-box $(text 28) $(text 37) \n"
  else
    STATUS[0]=$(text 27)
    error "\n Sing-box $(text 27) $(text 38) \n"
    # 如果启动失败，再尝试重启
    cmd_systemctl restart sing-box
  fi

  # 如果配置了 Argo，也启动 Argo 服务
  if [ -s ${ARGO_DAEMON_FILE} ]; then
    cmd_systemctl enable argo

    sleep 2

    # 检查 Argo 服务是否成功启动
    if cmd_systemctl status argo &>/dev/null; then
      STATUS[1]=$(text 28)
      info "\n Argo $(text 28) $(text 37) \n"
    else
      STATUS[1]=$(text 27)
      error "\n Argo $(text 27) $(text 38) \n"
      # 如果启动失败，再尝试重启
      cmd_systemctl restart argo
    fi
  fi
}

export_list() {
  IS_INSTALL=$1

  check_install

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
  ls ${WORK_DIR}/conf/*-ws*inbounds.json >/dev/null 2>&1 && [ "$IS_ARGO" = 'is_argo' ] && [ -z "$ARGO_DOMAIN" ] && [[ "${STATUS[1]}" = "$(text 28)" || "$NONINTERACTIVE_INSTALL" = 'noninteractive_install' ]] && fetch_quicktunnel_domain

  # 如果使用 Json 或者 Token Argo，则使用加密的而且是固定的 Argo 隧道域名，否则使用 IP:PORT 的 http 服务
  [[ "$ARGO_TYPE" = 'is_token_argo' || "$ARGO_TYPE" = 'is_json_argo' ]] && SUBSCRIBE_ADDRESS="https://$ARGO_DOMAIN" || SUBSCRIBE_ADDRESS="http://${SERVER_IP_1}:${PORT_NGINX}"

  # v1.3.0 (2025.11.10)及之后 reality 使用 xtls-rprx-vision 流控替代多路复用 multiplex，但为了兼容旧版本已安装的客户端 URI，在这里作判断
  if [ -n "$PORT_XTLS_REALITY" ]; then
    local FLOW="$(awk -F '"' '/"flow"/{print $4}' ${WORK_DIR}/conf/*_${NODE_TAG[0]}_inbounds.json)"

    if [ "${FLOW}" = 'xtls-rprx-vision' ]; then
      local VISION_OR_MUX_SHADOWROCKET='xtls=2' && local VISION_FLOW='&flow=xtls-rprx-vision' && local VISION_OR_MUX_CLASH=', flow: xtls-rprx-vision' && local MULTIPLEX_PADDING_ENABLED='false' && local VISION_BRUTAL_ENABLED='false'
    else
      local VISION_OR_MUX_SHADOWROCKET='mux=1' && local MULTIPLEX_PADDING_ENABLED='true' && local VISION_BRUTAL_ENABLED="${IS_BRUTAL}"
    fi
  fi

  # 获取自签证书指纹。origin rules 或者 argo 回源的是由 Google Trust Services（谷歌信任服务）作为中间 CA（CN=WE1）签发，受信任的证书（非自签名）
  SELF_SIGNED_FINGERPRINT_SHA256=$(openssl x509 -fingerprint -noout -sha256 -in ${WORK_DIR}/cert/cert.pem | awk -F '=' '{print $NF}')
  SELF_SIGNED_FINGERPRINT_BASE64=$(openssl x509 -in ${WORK_DIR}/cert/cert.pem -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | openssl enc -base64)

  # 生成各订阅文件
  # 生成 Clash proxy providers 订阅文件
  local CLASH_SUBSCRIBE='proxies:'

  [ -n "$PORT_XTLS_REALITY" ] && local CLASH_XTLS_REALITY="- {name: \"${NODE_NAME[11]} ${NODE_TAG[0]}\", type: vless, server: ${SERVER_IP}, port: ${PORT_XTLS_REALITY}, uuid: ${UUID[11]}, network: tcp, udp: true, tls: true${VISION_OR_MUX_CLASH}, servername: ${TLS_SERVER[11]}, client-fingerprint: firefox, reality-opts: {public-key: ${REALITY_PUBLIC[11]}, short-id: \"\"}, smux: { enabled: ${MULTIPLEX_PADDING_ENABLED}, protocol: 'h2mux', padding: ${MULTIPLEX_PADDING_ENABLED}, max-connections: '8', min-streams: '16', statistic: true, only-tcp: false }, brutal-opts: { enabled: ${VISION_BRUTAL_ENABLED}, up: '1000 Mbps', down: '1000 Mbps' } }" &&
  local CLASH_SUBSCRIBE+="
  $CLASH_XTLS_REALITY
"
  if [ -n "$PORT_HYSTERIA2" ]; then
    [[ -n "$PORT_HOPPING_START" && -n "$PORT_HOPPING_END" ]] && local CLASH_HOPPING=" ports: ${PORT_HOPPING_START}-${PORT_HOPPING_END}, HopInterval: 60,"
    local CLASH_HYSTERIA2="- {name: \"${NODE_NAME[12]} ${NODE_TAG[1]}\", type: hysteria2, server: ${SERVER_IP}, port: ${PORT_HYSTERIA2},${CLASH_HOPPING} up: \"200 Mbps\", down: \"1000 Mbps\", password: ${UUID[12]}, sni: ${TLS_SERVER_DEFAULT}, skip-cert-verify: false, fingerprint: ${SELF_SIGNED_FINGERPRINT_SHA256}}" &&
    local CLASH_SUBSCRIBE+="
  $CLASH_HYSTERIA2
"
  fi

  [ -n "$PORT_TUIC" ] && local CLASH_TUIC="- {name: \"${NODE_NAME[13]} ${NODE_TAG[2]}\", type: tuic, server: ${SERVER_IP}, port: ${PORT_TUIC}, uuid: ${UUID[13]}, password: ${TUIC_PASSWORD}, alpn: [h3], reduce-rtt: true, request-timeout: 8000, udp-relay-mode: native, congestion-controller: $TUIC_CONGESTION_CONTROL, sni: ${TLS_SERVER_DEFAULT}, skip-cert-verify: false, fingerprint: ${SELF_SIGNED_FINGERPRINT_SHA256}}" &&
  local CLASH_SUBSCRIBE+="
  $CLASH_TUIC
"
  [ -n "$PORT_SHADOWTLS" ] && local CLASH_SHADOWTLS="- {name: \"${NODE_NAME[14]} ${NODE_TAG[3]}\", type: ss, server: ${SERVER_IP}, port: ${PORT_SHADOWTLS}, cipher: $SHADOWTLS_METHOD, password: $SHADOWTLS_PASSWORD, plugin: shadow-tls, client-fingerprint: firefox, plugin-opts: {host: ${TLS_SERVER[14]}, password: \"${UUID[14]}\", version: 3}, smux: { enabled: true, protocol: 'h2mux', padding: true, max-connections: '8', min-streams: '16', statistic: true, only-tcp: false }, brutal-opts: { enabled: ${IS_BRUTAL}, up: '1000 Mbps', down: '1000 Mbps' } }" &&
  local CLASH_SUBSCRIBE+="
  $CLASH_SHADOWTLS
"

  [ -n "$PORT_SHADOWSOCKS" ] && local CLASH_SHADOWSOCKS="- {name: \"${NODE_NAME[15]} ${NODE_TAG[4]}\", type: ss, server: ${SERVER_IP}, port: $PORT_SHADOWSOCKS, cipher: ${SHADOWSOCKS_METHOD}, password: ${UUID[15]}, smux: { enabled: true, protocol: 'h2mux', padding: true, max-connections: '8', min-streams: '16', statistic: true, only-tcp: false }, brutal-opts: { enabled: ${IS_BRUTAL}, up: '1000 Mbps', down: '1000 Mbps' } }" &&
  local CLASH_SUBSCRIBE+="
  $CLASH_SHADOWSOCKS
"
  [ -n "$PORT_TROJAN" ] && local CLASH_TROJAN="- {name: \"${NODE_NAME[16]} ${NODE_TAG[5]}\", type: trojan, server: ${SERVER_IP}, port: $PORT_TROJAN, password: $TROJAN_PASSWORD, client-fingerprint: firefox, sni: ${TLS_SERVER_DEFAULT}, skip-cert-verify: false, fingerprint: ${SELF_SIGNED_FINGERPRINT_SHA256}, smux: { enabled: true, protocol: 'h2mux', padding: true, max-connections: '8', min-streams: '16', statistic: true, only-tcp: false }, brutal-opts: { enabled: ${IS_BRUTAL}, up: '1000 Mbps', down: '1000 Mbps' } }" &&
  local CLASH_SUBSCRIBE+="
  $CLASH_TROJAN
"
  if [ -n "$PORT_VMESS_WS" ]; then
    if [[ "${STATUS[1]}" =~ $(text 27)|$(text 28) ]] || [[ "$IS_ARGO" = 'is_argo' && "$NONINTERACTIVE_INSTALL" = 'noninteractive_install' ]]; then
      local CLASH_VMESS_WS="- {name: \"${NODE_NAME[17]} ${NODE_TAG[6]}\", type: vmess, server: ${CDN[17]}, port: 80, uuid: ${UUID[17]}, udp: true, tls: false, alterId: 0, cipher: auto, network: ws, ws-opts: { path: \"/$VMESS_WS_PATH\", headers: {Host: $ARGO_DOMAIN} }, smux: { enabled: true, protocol: 'h2mux', padding: true, max-connections: '8', min-streams: '16', statistic: true, only-tcp: false }, brutal-opts: { enabled: ${IS_BRUTAL}, up: '1000 Mbps', down: '1000 Mbps' } }" &&
      local CLASH_SUBSCRIBE+="
  $CLASH_VMESS_WS
"
      [ "$ARGO_TYPE" = 'is_token_argo' ] && CLASH_SUBSCRIBE+="
  # $(text 94)
"
    else
      local CLASH_VMESS_WS="- {name: \"${NODE_NAME[17]} ${NODE_TAG[6]}\", type: vmess, server: ${CDN[17]}, port: 80, uuid: ${UUID[17]}, udp: true, tls: false, alterId: 0, cipher: auto, network: ws, ws-opts: { path: \"/$VMESS_WS_PATH\", headers: {Host: $VMESS_HOST_DOMAIN} }, smux: { enabled: true, protocol: 'h2mux', padding: true, max-connections: '8', min-streams: '16', statistic: true, only-tcp: false }, brutal-opts: { enabled: ${IS_BRUTAL}, up: '1000 Mbps', down: '1000 Mbps' } }" &&
      local WS_SERVER_IP_SHOW=${WS_SERVER_IP[17]} && local TYPE_HOST_DOMAIN=$VMESS_HOST_DOMAIN && local TYPE_PORT_WS=$PORT_VMESS_WS &&
      local CLASH_SUBSCRIBE+="
  $CLASH_VMESS_WS

  # $(text 52)
"
    fi
  fi

  if [ -n "$PORT_VLESS_WS" ]; then
     if [[ "${STATUS[1]}" =~ $(text 27)|$(text 28) ]] || [[ "$IS_ARGO" = 'is_argo' && "$NONINTERACTIVE_INSTALL" = 'noninteractive_install' ]]; then
      local CLASH_VLESS_WS="- {name: \"${NODE_NAME[18]} ${NODE_TAG[7]}\", type: vless, server: ${CDN[18]}, port: 443, uuid: ${UUID[18]}, udp: true, tls: true, servername: $ARGO_DOMAIN, network: ws, skip-cert-verify: false, ws-opts: { path: \"/$VLESS_WS_PATH\", headers: {Host: $ARGO_DOMAIN}, max-early-data: 2560, early-data-header-name: Sec-WebSocket-Protocol }, smux: { enabled: true, protocol: 'h2mux', padding: true, max-connections: '8', min-streams: '16', statistic: true, only-tcp: false }, brutal-opts: { enabled: ${IS_BRUTAL}, up: '1000 Mbps', down: '1000 Mbps' } }" &&
      local CLASH_SUBSCRIBE+="
  $CLASH_VLESS_WS
"
      [ "$ARGO_TYPE" = 'is_token_argo' ] && CLASH_SUBSCRIBE+="
  # $(text 94)
"
    else
      local CLASH_VLESS_WS="- {name: \"${NODE_NAME[18]} ${NODE_TAG[7]}\", type: vless, server: ${CDN[18]}, port: 443, uuid: ${UUID[18]}, udp: true, tls: true, servername: $VLESS_HOST_DOMAIN, network: ws, skip-cert-verify: false, ws-opts: { path: \"/$VLESS_WS_PATH\", headers: {Host: $VLESS_HOST_DOMAIN}, max-early-data: 2560, early-data-header-name: Sec-WebSocket-Protocol }, smux: { enabled: true, protocol: 'h2mux', padding: true, max-connections: '8', min-streams: '16', statistic: true, only-tcp: false }, brutal-opts: { enabled: ${IS_BRUTAL}, up: '1000 Mbps', down: '1000 Mbps' } }" &&
      local WS_SERVER_IP_SHOW=${WS_SERVER_IP[18]} && local TYPE_HOST_DOMAIN=$VLESS_HOST_DOMAIN && local TYPE_PORT_WS=$PORT_VLESS_WS &&
      local CLASH_SUBSCRIBE+="
  $CLASH_VLESS_WS

  # $(text 52)
"
    fi
  fi

  [ -n "$PORT_H2_REALITY" ] && local CLASH_H2_REALITY="- {name: \"${NODE_NAME[19]} ${NODE_TAG[8]}\", type: vless, server: ${SERVER_IP}, port: ${PORT_H2_REALITY}, uuid: ${UUID[19]}, network: http, tls: true, servername: ${TLS_SERVER[19]}, client-fingerprint: firefox, reality-opts: { public-key: ${REALITY_PUBLIC[19]}, short-id: \"\" }, smux: { enabled: true, protocol: 'h2mux', padding: true, max-connections: '8', min-streams: '16', statistic: true, only-tcp: false }, brutal-opts: { enabled: ${IS_BRUTAL}, up: '1000 Mbps', down: '1000 Mbps' } }" &&
  local CLASH_SUBSCRIBE+="
  $CLASH_H2_REALITY
"

  [ -n "$PORT_GRPC_REALITY" ] && local CLASH_GRPC_REALITY="- {name: \"${NODE_NAME[20]} ${NODE_TAG[9]}\", type: vless, server: ${SERVER_IP}, port: ${PORT_GRPC_REALITY}, uuid: ${UUID[20]}, network: grpc, tls: true, udp: true, flow: , client-fingerprint: firefox, servername: ${TLS_SERVER[20]}, grpc-opts: {  grpc-service-name: \"grpc\" }, reality-opts: { public-key: ${REALITY_PUBLIC[20]}, short-id: \"\" }, smux: { enabled: true, protocol: 'h2mux', padding: true, max-connections: '8', min-streams: '16', statistic: true, only-tcp: false }, brutal-opts: { enabled: ${IS_BRUTAL}, up: '1000 Mbps', down: '1000 Mbps' } }" &&
  local CLASH_SUBSCRIBE+="
  $CLASH_GRPC_REALITY
"

  [ -n "$PORT_ANYTLS" ] && local CLASH_ANYTLS="- {name: \"${NODE_NAME[21]} ${NODE_TAG[10]}\", type: anytls, server: ${SERVER_IP}, port: $PORT_ANYTLS, password: ${UUID[21]}, client-fingerprint: firefox, udp: true, idle-session-check-interval: 30, idle-session-timeout: 30, sni: ${TLS_SERVER_DEFAULT}, skip-cert-verify: false, fingerprint: ${SELF_SIGNED_FINGERPRINT_SHA256} }" &&
  local CLASH_SUBSCRIBE+="
  $CLASH_ANYTLS
"

  echo -n "${CLASH_SUBSCRIBE}" | sed -E '/^[ ]*#|^--/d' | sed '/^$/d' > ${WORK_DIR}/subscribe/proxies

  # 后台生成 clash 订阅配置文件
  {
    # 模板1: 使用 proxy providers
    wget --no-check-certificate -qO- --tries=3 --timeout=2 ${GH_PROXY}${SUBSCRIBE_TEMPLATE}/clash | sed "s#NODE_NAME#${NODE_NAME_CONFIRM}#g; s#PROXY_PROVIDERS_URL#$SUBSCRIBE_ADDRESS/${UUID_CONFIRM}/proxies#" > ${WORK_DIR}/subscribe/clash

    # 模板2: 不使用 proxy providers
    CLASH2_PORT=("$PORT_XTLS_REALITY" "$PORT_HYSTERIA2" "$PORT_TUIC" "$PORT_SHADOWTLS" "$PORT_SHADOWSOCKS" "$PORT_TROJAN" "$PORT_VMESS_WS" "$PORT_VLESS_WS" "$PORT_GRPC_REALITY" "$PORT_ANYTLS")
    CLASH2_PROXY_INSERT=("$CLASH_XTLS_REALITY" "$CLASH_HYSTERIA2" "$CLASH_TUIC" "$CLASH_SHADOWTLS" "$CLASH_SHADOWSOCKS" "$CLASH_TROJAN" "$CLASH_VMESS_WS" "$CLASH_VLESS_WS" "$CLASH_GRPC_REALITY" "$CLASH_ANYTLS")
    CLASH2_PROXY_GROUPS_INSERT=("- ${NODE_NAME[11]} ${NODE_TAG[0]}" "- ${NODE_NAME[12]} ${NODE_TAG[1]}" "- ${NODE_NAME[13]} ${NODE_TAG[2]}" "- ${NODE_NAME[14]} ${NODE_TAG[3]}" "- ${NODE_NAME[15]} ${NODE_TAG[4]}" "- ${NODE_NAME[16]} ${NODE_TAG[5]}" "- ${NODE_NAME[17]} ${NODE_TAG[6]}" "- ${NODE_NAME[18]} ${NODE_TAG[7]}" "- ${NODE_NAME[20]} ${NODE_TAG[9]}" "- ${NODE_NAME[21]} ${NODE_TAG[10]}")

    CLASH2_YAML=$(wget --no-check-certificate -qO- --tries=3 --timeout=2 ${GH_PROXY}${SUBSCRIBE_TEMPLATE}/clash2)
    for x in ${!CLASH2_PORT[@]}; do
      [[ ${CLASH2_PORT[x]} =~ [0-9]+ ]] && { CLASH2_YAML=$(sed "/proxy-groups:/i\  ${CLASH2_PROXY_INSERT[x]}" <<< "$CLASH2_YAML"); CLASH2_YAML=$(sed -E "/- name: (♻️ 自动选择|📲 电报消息|💬 OpenAi|📹 油管视频|🎥 奈飞视频|📺 巴哈姆特|📺 哔哩哔哩|🌍 国外媒体|🌏 国内媒体|📢 谷歌FCM|Ⓜ️ 微软Bing|Ⓜ️ 微软云盘|Ⓜ️ 微软服务|🍎 苹果服务|🎮 游戏平台|🎶 网易音乐|🎯 全球直连)|^rules:$/i\      ${CLASH2_PROXY_GROUPS_INSERT[x]}" <<< "$CLASH2_YAML"); }
    done
    echo "$CLASH2_YAML" > ${WORK_DIR}/subscribe/clash2
  } &>/dev/null

  # 生成 ShadowRocket 订阅配置文件
  [ -n "$PORT_XTLS_REALITY" ] && local SHADOWROCKET_SUBSCRIBE+="
vless://$(echo -n "auto:${UUID[11]}@${SERVER_IP_2}:${PORT_XTLS_REALITY}" | base64 -w0)?remarks=${NODE_NAME[11]// /%20}%20${NODE_TAG[0]}&tls=1&peer=${TLS_SERVER[11]}&${VISION_OR_MUX_SHADOWROCKET}&pbk=${REALITY_PUBLIC[11]}
"
  if [ -n "$PORT_HYSTERIA2" ]; then
    [[ -n "$PORT_HOPPING_START" && -n "$PORT_HOPPING_END" ]] && local SHADOWROCKET_HOPPING="&mport=${PORT_HYSTERIA2},${PORT_HOPPING_START}-${PORT_HOPPING_END}"
    local SHADOWROCKET_SUBSCRIBE+="
hysteria2://${UUID[12]}@${SERVER_IP_1}:${PORT_HYSTERIA2}?peer=${TLS_SERVER_DEFAULT}&hpkp=${SELF_SIGNED_FINGERPRINT_SHA256}&obfs=none${SHADOWROCKET_HOPPING}#${NODE_NAME[12]// /%20}%20${NODE_TAG[1]}
"
  fi
  [ -n "$PORT_TUIC" ] && local SHADOWROCKET_SUBSCRIBE+="
tuic://${TUIC_PASSWORD}:${UUID[13]}@${SERVER_IP_2}:${PORT_TUIC}?peer=${TLS_SERVER_DEFAULT}&congestion_control=$TUIC_CONGESTION_CONTROL&udp_relay_mode=native&alpn=h3&hpkp=${SELF_SIGNED_FINGERPRINT_SHA256}#${NODE_NAME[13]// /%20}%20${NODE_TAG[2]}
"
  [ -n "$PORT_SHADOWTLS" ] && local SHADOWROCKET_SUBSCRIBE+="
ss://$(echo -n "$SHADOWTLS_METHOD:$SHADOWTLS_PASSWORD@${SERVER_IP_2}:${PORT_SHADOWTLS}" | base64 -w0)?shadow-tls=$(echo -n "{\"version\":\"3\",\"host\":\"${TLS_SERVER[14]}\",\"password\":\"${UUID[14]}\"}" | base64 -w0)#${NODE_NAME[14]// /%20}%20${NODE_TAG[3]}
"
  [ -n "$PORT_SHADOWSOCKS" ] && local SHADOWROCKET_SUBSCRIBE+="
ss://$(echo -n "${SHADOWSOCKS_METHOD}:${UUID[15]}@${SERVER_IP_2}:$PORT_SHADOWSOCKS" | base64 -w0)#${NODE_NAME[15]// /%20}%20${NODE_TAG[4]}
"
  [ -n "$PORT_TROJAN" ] && local SHADOWROCKET_SUBSCRIBE+="
trojan://${TROJAN_PASSWORD}@${SERVER_IP_1}:$PORT_TROJAN?peer=${TLS_SERVER_DEFAULT}&hpkp=${SELF_SIGNED_FINGERPRINT_SHA256}#${NODE_NAME[16]// /%20}%20${NODE_TAG[5]}
"
  if [ -n "$PORT_VMESS_WS" ]; then
     if [[ "${STATUS[1]}" =~ $(text 27)|$(text 28) ]] || [[ "$IS_ARGO" = 'is_argo' && "$NONINTERACTIVE_INSTALL" = 'noninteractive_install' ]]; then
      local SHADOWROCKET_SUBSCRIBE+="
----------------------------
vmess://$(echo -n "auto:${UUID[17]}@${CDN[17]}:80" | base64 -w0)?remarks=${NODE_NAME[17]// /%20}%20${NODE_TAG[6]}&obfsParam=$ARGO_DOMAIN&path=/$VMESS_WS_PATH&obfs=websocket&alterId=0
"
      [ "$ARGO_TYPE" = 'is_token_argo' ] && SHADOWROCKET_SUBSCRIBE+="
  # $(text 94)
"
    else
      WS_SERVER_IP_SHOW=${WS_SERVER_IP[17]} && TYPE_HOST_DOMAIN=$VMESS_HOST_DOMAIN && TYPE_PORT_WS=$PORT_VMESS_WS && local SHADOWROCKET_SUBSCRIBE+="
----------------------------
vmess://$(echo -n "auto:${UUID[17]}@${CDN[17]}:80" | base64 -w0)?remarks=${NODE_NAME[17]// /%20}%20${NODE_TAG[6]}&obfsParam=$VMESS_HOST_DOMAIN&path=/$VMESS_WS_PATH&obfs=websocket&alterId=0

# $(text 52)
"
    fi
  fi

  if [ -n "$PORT_VLESS_WS" ]; then
     if [[ "${STATUS[1]}" =~ $(text 27)|$(text 28) ]] || [[ "$IS_ARGO" = 'is_argo' && "$NONINTERACTIVE_INSTALL" = 'noninteractive_install' ]]; then
      local SHADOWROCKET_SUBSCRIBE+="
----------------------------
vless://$(echo -n "auto:${UUID[18]}@${CDN[18]}:443" | base64 -w0)?remarks=${NODE_NAME[18]// /%20}%20${NODE_TAG[7]}&obfsParam=$ARGO_DOMAIN&path=/$VLESS_WS_PATH?ed=2560&obfs=websocket&tls=1&peer=$ARGO_DOMAIN
"
      [ "$ARGO_TYPE" = 'is_token_argo' ] && SHADOWROCKET_SUBSCRIBE+="
  # $(text 94)
"
    else
      WS_SERVER_IP_SHOW=${WS_SERVER_IP[18]} && TYPE_HOST_DOMAIN=$VLESS_HOST_DOMAIN && TYPE_PORT_WS=$PORT_VLESS_WS && local SHADOWROCKET_SUBSCRIBE+="
----------------------------
vless://$(echo -n "auto:${UUID[18]}@${CDN[18]}:443" | base64 -w0)?remarks=${NODE_NAME[18]// /%20}%20${NODE_TAG[7]}&obfsParam=$VLESS_HOST_DOMAIN&path=/$VLESS_WS_PATH?ed=2560&obfs=websocket&tls=1&peer=$VLESS_HOST_DOMAIN

# $(text 52)
"
    fi
  fi

  [ -n "$PORT_H2_REALITY" ] && local SHADOWROCKET_SUBSCRIBE+="
----------------------------
vless://$(echo -n auto:${UUID[19]}@${SERVER_IP_2}:${PORT_H2_REALITY} | base64 -w0)?remarks=${NODE_NAME[19]// /%20}%20${NODE_TAG[8]}&path=/&obfs=h2&tls=1&peer=${TLS_SERVER[19]}&alpn=h2&mux=1&pbk=${REALITY_PUBLIC[19]}
"
  [ -n "$PORT_GRPC_REALITY" ] && local SHADOWROCKET_SUBSCRIBE+="
vless://$(echo -n "auto:${UUID[20]}@${SERVER_IP_2}:${PORT_GRPC_REALITY}" | base64 -w0)?remarks=${NODE_NAME[20]// /%20}%20${NODE_TAG[9]}&path=grpc&obfs=grpc&tls=1&peer=${TLS_SERVER[20]}&pbk=${REALITY_PUBLIC[20]}
"
  [ -n "$PORT_ANYTLS" ] && local SHADOWROCKET_SUBSCRIBE+="
anytls://${UUID[21]}@${SERVER_IP_1}:${PORT_ANYTLS}?peer=${TLS_SERVER_DEFAULT}&udp=1&hpkp=${SELF_SIGNED_FINGERPRINT_SHA256}#${NODE_NAME[21]// /%20}%20${NODE_TAG[10]}
"
  echo -n "$SHADOWROCKET_SUBSCRIBE" | sed -E '/^[ ]*#|^--/d' | sed '/^$/d' | base64 -w0 > ${WORK_DIR}/subscribe/shadowrocket

  # 生成 V2rayN 订阅文件
  [ -n "$PORT_XTLS_REALITY" ] && local V2RAYN_SUBSCRIBE+="
----------------------------
vless://${UUID[11]}@${SERVER_IP_1}:${PORT_XTLS_REALITY}?encryption=none${VISION_FLOW}&security=reality&sni=${TLS_SERVER[11]}&fp=firefox&pbk=${REALITY_PUBLIC[11]}&type=tcp&headerType=none#${NODE_NAME[11]// /%20}%20${NODE_TAG[0]}"

  [ -n "$PORT_HYSTERIA2" ] && local V2RAYN_SUBSCRIBE+="
----------------------------
hysteria2://${UUID[12]}@${SERVER_IP_1}:${PORT_HYSTERIA2}?sni=${TLS_SERVER_DEFAULT}&alpn=h3&insecure=1&allowInsecure=1&pinSHA256=${SELF_SIGNED_FINGERPRINT_SHA256//:/}#${NODE_NAME[12]// /%20}%20${NODE_TAG[1]}"

  [ -n "$PORT_TUIC" ] && local V2RAYN_SUBSCRIBE+="
----------------------------
tuic://${UUID[13]}:${TUIC_PASSWORD}@${SERVER_IP_1}:${PORT_TUIC}?sni=${TLS_SERVER_DEFAULT}&alpn=h3&insecure=1&allowInsecure=1&congestion_control=$TUIC_CONGESTION_CONTROL#${NODE_NAME[13]// /%20}%20${NODE_TAG[2]}"

  [ -n "$PORT_SHADOWTLS" ] && local V2RAYN_SUBSCRIBE+="
----------------------------
# $(text 54)

{
    \"log\":{
        \"level\":\"warn\"
    },
    \"inbounds\":[
        {
            \"listen\":\"127.0.0.1\",
            \"listen_port\":${PORT_SHADOWTLS},
            \"sniff\":true,
            \"sniff_override_destination\":false,
            \"tag\": \"${PROTOCOL_LIST[3]}\",
            \"type\":\"mixed\"
        }
    ],
    \"outbounds\":[
        {
            \"detour\":\"shadowtls-out\",
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
            \"password\":\"${UUID[14]}\",
            \"server\":\"${SERVER_IP}\",
            \"server_port\":${PORT_SHADOWTLS},
            \"tag\": \"shadowtls-out\",
            \"tls\":{
                \"enabled\":true,
                \"server_name\":\"${TLS_SERVER[14]}\",
                \"utls\": {
                  \"enabled\": true,
                  \"fingerprint\": \"firefox\"
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
trojan://$TROJAN_PASSWORD@${SERVER_IP_1}:$PORT_TROJAN?security=tls&insecure=1&allowInsecure=1&pcs=${SELF_SIGNED_FINGERPRINT_SHA256//:/}&type=tcp&headerType=none#${NODE_NAME[16]// /%20}%20${NODE_TAG[5]}"

  if [ -n "$PORT_VMESS_WS" ]; then
     if [[ "${STATUS[1]}" =~ $(text 27)|$(text 28) ]] || [[ "$IS_ARGO" = 'is_argo' && "$NONINTERACTIVE_INSTALL" = 'noninteractive_install' ]]; then
      local V2RAYN_SUBSCRIBE+="
----------------------------
vmess://$(echo -n "{ \"v\": \"2\", \"ps\": \"${NODE_NAME[17]} ${NODE_TAG[6]}\", \"add\": \"${CDN[18]}\", \"port\": \"80\", \"id\": \"${UUID[18]}\", \"aid\": \"0\", \"scy\": \"none\", \"net\": \"ws\", \"type\": \"auto\", \"host\": \"$ARGO_DOMAIN\", \"path\": \"/$VMESS_WS_PATH\", \"tls\": \"\", \"sni\": \"\", \"alpn\": \"\" }" | base64 -w0)"
      [ "$ARGO_TYPE" = 'is_token_argo' ] && V2RAYN_SUBSCRIBE+="

  # $(text 94)
"
    else
      WS_SERVER_IP_SHOW=${WS_SERVER_IP[17]} && TYPE_HOST_DOMAIN=$VMESS_HOST_DOMAIN && TYPE_PORT_WS=$PORT_VMESS_WS && local V2RAYN_SUBSCRIBE+="
----------------------------
vmess://$(echo -n "{ \"v\": \"2\", \"ps\": \"${NODE_NAME[17]} ${NODE_TAG[6]}\", \"add\": \"${CDN[18]}\", \"port\": \"80\", \"id\": \"${UUID[18]}\", \"aid\": \"0\", \"scy\": \"none\", \"net\": \"ws\", \"type\": \"auto\", \"host\": \"$VMESS_HOST_DOMAIN\", \"path\": \"/$VMESS_WS_PATH\", \"tls\": \"\", \"sni\": \"\", \"alpn\": \"\" }" | base64 -w0)

# $(text 52)"
    fi
  fi

  if [ -n "$PORT_VLESS_WS" ]; then
     if [[ "${STATUS[1]}" =~ $(text 27)|$(text 28) ]] || [[ "$IS_ARGO" = 'is_argo' && "$NONINTERACTIVE_INSTALL" = 'noninteractive_install' ]]; then
      local V2RAYN_SUBSCRIBE+="
----------------------------
vless://${UUID[18]}@${CDN[18]}:443?encryption=none&security=tls&sni=$ARGO_DOMAIN&type=ws&host=$ARGO_DOMAIN&path=%2F$VLESS_WS_PATH%3Fed%3D2560#${NODE_NAME[18]// /%20}%20${NODE_TAG[7]}"
      [ "$ARGO_TYPE" = 'is_token_argo' ] && V2RAYN_SUBSCRIBE+="

  # $(text 94)
"
    else
      WS_SERVER_IP_SHOW=${WS_SERVER_IP[18]} && TYPE_HOST_DOMAIN=$VLESS_HOST_DOMAIN && TYPE_PORT_WS=$PORT_VLESS_WS && local V2RAYN_SUBSCRIBE+="
----------------------------
vless://${UUID[18]}@${CDN[18]}:443?encryption=none&security=tls&sni=$VLESS_HOST_DOMAIN&type=ws&host=$VLESS_HOST_DOMAIN&path=%2F$VLESS_WS_PATH%3Fed%3D2560#${NODE_NAME[18]// /%20}%20${NODE_TAG[7]}

# $(text 52)"
    fi
  fi

  [ -n "$PORT_H2_REALITY" ] && local V2RAYN_SUBSCRIBE+="
----------------------------
vless://${UUID[19]}@${SERVER_IP_1}:${PORT_H2_REALITY}?encryption=none&security=reality&sni=${TLS_SERVER[19]}&fp=firefox&pbk=${REALITY_PUBLIC[19]}&type=http#${NODE_NAME[19]// /%20}%20${NODE_TAG[8]}"

  [ -n "$PORT_GRPC_REALITY" ] && local V2RAYN_SUBSCRIBE+="
----------------------------
vless://${UUID[20]}@${SERVER_IP_1}:${PORT_GRPC_REALITY}?encryption=none&security=reality&sni=${TLS_SERVER[20]}&fp=firefox&pbk=${REALITY_PUBLIC[20]}&type=grpc&serviceName=grpc&mode=gun#${NODE_NAME[20]// /%20}%20${NODE_TAG[9]}"

  [ -n "$PORT_ANYTLS" ] && local V2RAYN_SUBSCRIBE+="
----------------------------
anytls://${UUID[21]}@${SERVER_IP_1}:${PORT_ANYTLS}?security=tls&sni=${TLS_SERVER_DEFAULT}&fp=firefox&insecure=1&allowInsecure=1&type=tcp#${NODE_NAME[21]// /%20}%20${NODE_TAG[10]}"

  echo -n "$V2RAYN_SUBSCRIBE" | sed -E '/^[ ]*#|^[ ]+|^--|^\{|^\}/d' | sed '/^$/d' | base64 -w0 > ${WORK_DIR}/subscribe/v2rayn

  # 生成 NekoBox 订阅文件
  [ -n "$PORT_XTLS_REALITY" ] && local NEKOBOX_SUBSCRIBE+="
----------------------------
vless://${UUID[11]}@${SERVER_IP_1}:${PORT_XTLS_REALITY}?security=reality&sni=${TLS_SERVER[11]}&fp=firefox&pbk=${REALITY_PUBLIC[11]}&type=tcp${VISION_FLOW}&encryption=none#${NODE_NAME[11]// /%20}%20${NODE_TAG[0]}"

  if [ -n "$PORT_HYSTERIA2" ]; then
    [[ -n "$PORT_HOPPING_START" && -n "$PORT_HOPPING_END" ]] && NEKOBOX_HOPPING="mport=${PORT_HOPPING_START}-${PORT_HOPPING_END}&"
    local NEKOBOX_SUBSCRIBE+="
----------------------------
hy2://${UUID[12]}@${SERVER_IP_1}:${PORT_HYSTERIA2}?${NEKOBOX_HOPPING}insecure=1&sni=${TLS_SERVER_DEFAULT}#${NODE_NAME[12]// /%20}%20${NODE_TAG[1]}"
  fi

  [ -n "$PORT_TUIC" ] && local NEKOBOX_SUBSCRIBE+="
----------------------------
tuic://${TUIC_PASSWORD}:${UUID[13]}@${SERVER_IP_1}:${PORT_TUIC}?congestion_control=$TUIC_CONGESTION_CONTROL&alpn=h3&sni=${TLS_SERVER_DEFAULT}&udp_relay_mode=native&allow_insecure=1#${NODE_NAME[13]// /%20}%20${NODE_TAG[2]}"
  [ -n "$PORT_SHADOWTLS" ] && local NEKOBOX_SUBSCRIBE+="
----------------------------
nekoray://custom#$(echo -n "{\"_v\":0,\"addr\":\"127.0.0.1\",\"cmd\":[\"\"],\"core\":\"internal\",\"cs\":\"{\n    \\\"password\\\": \\\"${UUID[14]}\\\",\n    \\\"server\\\": \\\"${SERVER_IP_1}\\\",\n    \\\"server_port\\\": ${PORT_SHADOWTLS},\n    \\\"tag\\\": \\\"shadowtls-out\\\",\n    \\\"tls\\\": {\n        \\\"enabled\\\": true,\n        \\\"server_name\\\": \\\"${TLS_SERVER[14]}\\\"\n    },\n    \\\"type\\\": \\\"shadowtls\\\",\n    \\\"version\\\": 3\n}\n\",\"mapping_port\":0,\"name\":\"1-tls-not-use\",\"port\":1080,\"socks_port\":0}" | base64 -w0)

nekoray://shadowsocks#$(echo -n "{\"_v\":0,\"method\":\"$SHADOWTLS_METHOD\",\"name\":\"2-ss-not-use\",\"pass\":\"$SHADOWTLS_PASSWORD\",\"port\":0,\"stream\":{\"ed_len\":0,\"insecure\":false,\"mux_s\":0,\"net\":\"tcp\"},\"uot\":0}" | base64 -w0)"

  [ -n "$PORT_SHADOWSOCKS" ] && local NEKOBOX_SUBSCRIBE+="
----------------------------
ss://$(echo -n "${SHADOWSOCKS_METHOD}:${UUID[15]}" | base64 -w0)@${SERVER_IP_1}:$PORT_SHADOWSOCKS#${NODE_NAME[15]// /%20}%20${NODE_TAG[4]}"

  [ -n "$PORT_TROJAN" ] && local NEKOBOX_SUBSCRIBE+="
----------------------------
trojan://${TROJAN_PASSWORD}@${SERVER_IP_1}:$PORT_TROJAN?security=tls&sni=${TLS_SERVER_DEFAULT}&allowInsecure=1&fp=firefox&type=tcp#${NODE_NAME[16]// /%20}%20${NODE_TAG[5]}"

  if [ -n "$PORT_VMESS_WS" ]; then
     if [[ "${STATUS[1]}" =~ $(text 27)|$(text 28) ]] || [[ "$IS_ARGO" = 'is_argo' && "$NONINTERACTIVE_INSTALL" = 'noninteractive_install' ]]; then
      NEKOBOX_SUBSCRIBE+="
----------------------------
vmess://$(echo -n "{\"add\":\"${CDN[17]}\",\"aid\":\"0\",\"host\":\"$ARGO_DOMAIN\",\"id\":\"${UUID[17]}\",\"net\":\"ws\",\"path\":\"/$VMESS_WS_PATH\",\"port\":\"80\",\"ps\":\"${NODE_NAME[17]} ${NODE_TAG[6]}\",\"scy\":\"auto\",\"sni\":\"\",\"tls\":\"\",\"type\":\"\",\"v\":\"2\"}" | base64 -w0)"
      [ "$ARGO_TYPE" = 'is_token_argo' ] && NEKOBOX_SUBSCRIBE+="

  # $(text 94)
"
    else
      WS_SERVER_IP_SHOW=${WS_SERVER_IP[17]} && TYPE_HOST_DOMAIN=$VMESS_HOST_DOMAIN && TYPE_PORT_WS=$PORT_VMESS_WS && local NEKOBOX_SUBSCRIBE+="
----------------------------
vmess://$(echo -n "{\"add\":\"${CDN[17]}\",\"aid\":\"0\",\"host\":\"$VMESS_HOST_DOMAIN\",\"id\":\"${UUID[17]}\",\"net\":\"ws\",\"path\":\"/$VMESS_WS_PATH\",\"port\":\"80\",\"ps\":\"${NODE_NAME[17]} ${NODE_TAG[6]}\",\"scy\":\"auto\",\"sni\":\"\",\"tls\":\"\",\"type\":\"\",\"v\":\"2\"}" | base64 -w0)

# $(text 52)"
    fi
  fi

  if [ -n "$PORT_VLESS_WS" ]; then
     if [[ "${STATUS[1]}" =~ $(text 27)|$(text 28) ]] || [[ "$IS_ARGO" = 'is_argo' && "$NONINTERACTIVE_INSTALL" = 'noninteractive_install' ]]; then
      local NEKOBOX_SUBSCRIBE+="
----------------------------
vless://${UUID[18]}@${CDN[18]}:443?security=tls&sni=$ARGO_DOMAIN&type=ws&path=/$VLESS_WS_PATH?ed%3D2560&host=$ARGO_DOMAIN&encryption=zero#${NODE_NAME[18]// /%20}%20${NODE_TAG[7]}"
      [ "$ARGO_TYPE" = 'is_token_argo' ] && NEKOBOX_SUBSCRIBE+="

  # $(text 94)
"
    else
      WS_SERVER_IP_SHOW=${WS_SERVER_IP[18]} && TYPE_HOST_DOMAIN=$VLESS_HOST_DOMAIN && TYPE_PORT_WS=$PORT_VLESS_WS && local NEKOBOX_SUBSCRIBE+="
----------------------------
vless://${UUID[18]}@${CDN[18]}:443?security=tls&sni=$VLESS_HOST_DOMAIN&type=ws&path=/$VLESS_WS_PATH?ed%3D2560&host=$VLESS_HOST_DOMAIN&encryption=zero#${NODE_NAME[18]// /%20}%20${NODE_TAG[7]}

# $(text 52)"
    fi
  fi

  [ -n "$PORT_H2_REALITY" ] && local NEKOBOX_SUBSCRIBE+="
----------------------------
vless://${UUID[19]}@${SERVER_IP_1}:${PORT_H2_REALITY}?security=reality&sni=${TLS_SERVER[19]}&alpn=h2&fp=firefox&pbk=${REALITY_PUBLIC[19]// /%20}&type=http&encryption=none#${NODE_NAME[19]// /%20}%20${NODE_TAG[8]}"

  [ -n "$PORT_GRPC_REALITY" ] && local NEKOBOX_SUBSCRIBE+="
----------------------------
vless://${UUID[20]}@${SERVER_IP_1}:${PORT_GRPC_REALITY}?security=reality&sni=${TLS_SERVER[20]}&fp=firefox&pbk=${REALITY_PUBLIC[20]// /%20}&type=grpc&serviceName=grpc&encryption=none#${NODE_NAME[20]// /%20}%20${NODE_TAG[9]}"

  [ -n "$PORT_ANYTLS" ] && local NEKOBOX_SUBSCRIBE+="
----------------------------
anytls://${UUID[21]}@${SERVER_IP_1}:${PORT_ANYTLS}?security=tls&sni=${TLS_SERVER_DEFAULT}&insecure=1&fp=firefox#${NODE_NAME[21]// /%20}%20${NODE_TAG[10]}"

  echo -n "$NEKOBOX_SUBSCRIBE" | sed -E '/^[ ]*#|^--/d' | sed '/^$/d' | base64 -w0 > ${WORK_DIR}/subscribe/neko

  # 生成 Sing-box 订阅文件
  [ -n "$PORT_XTLS_REALITY" ] &&
  local OUTBOUND_REPLACE+=" { \"type\": \"vless\", \"tag\": \"${NODE_NAME[11]} ${NODE_TAG[0]}\", \"server\":\"${SERVER_IP}\", \"server_port\":${PORT_XTLS_REALITY}, \"uuid\":\"${UUID[11]}\", \"flow\":\"${FLOW}\", \"tls\":{ \"enabled\":true, \"server_name\":\"${TLS_SERVER[11]}\", \"utls\":{ \"enabled\":true, \"fingerprint\":\"firefox\" }, \"reality\":{ \"enabled\":true, \"public_key\":\"${REALITY_PUBLIC[11]}\", \"short_id\":\"\" } }, \"multiplex\": { \"enabled\": ${MULTIPLEX_PADDING_ENABLED}, \"protocol\": \"h2mux\", \"max_connections\": 8, \"min_streams\": 16, \"padding\": ${MULTIPLEX_PADDING_ENABLED}, \"brutal\":{ \"enabled\":${VISION_BRUTAL_ENABLED}, \"up_mbps\":1000, \"down_mbps\":1000 } } }," &&
  local NODE_REPLACE+="\"${NODE_NAME[11]} ${NODE_TAG[0]}\","

  if [ -n "$PORT_HYSTERIA2" ]; then
    local OUTBOUND_REPLACE+=" { \"type\": \"hysteria2\", \"tag\": \"${NODE_NAME[12]} ${NODE_TAG[1]}\", \"server\": \"${SERVER_IP}\", \"server_port\": ${PORT_HYSTERIA2},"
    [[ -n "${PORT_HOPPING_START}" && -n "${PORT_HOPPING_END}" ]] && local OUTBOUND_REPLACE+=" \"server_ports\": [ \"${PORT_HOPPING_START}:${PORT_HOPPING_END}\" ],"
    local OUTBOUND_REPLACE+=" \"up_mbps\": 200, \"down_mbps\": 1000, \"password\": \"${UUID[12]}\", \"tls\": { \"enabled\": true, \"server_name\": \"${TLS_SERVER_DEFAULT}\", \"certificate_public_key_sha256\": [\"$SELF_SIGNED_FINGERPRINT_BASE64\"], \"alpn\": [ \"h3\" ] } },"
    local NODE_REPLACE+="\"${NODE_NAME[12]} ${NODE_TAG[1]}\","
  fi

  [ -n "$PORT_TUIC" ] &&
  local TUIC_INBOUND=" { \"type\": \"tuic\", \"tag\": \"${NODE_NAME[13]} ${NODE_TAG[2]}\", \"server\": \"${SERVER_IP}\", \"server_port\": ${PORT_TUIC}, \"uuid\": \"${UUID[13]}\", \"password\": \"${TUIC_PASSWORD}\", \"congestion_control\": \"$TUIC_CONGESTION_CONTROL\", \"udp_relay_mode\": \"native\", \"zero_rtt_handshake\": false, \"heartbeat\": \"10s\", \"tls\": { \"enabled\": true, \"server_name\": \"${TLS_SERVER_DEFAULT}\", \"certificate_public_key_sha256\": [\"$SELF_SIGNED_FINGERPRINT_BASE64\"], \"alpn\": [ \"h3\" ] } }," &&
  local OUTBOUND_REPLACE+="${TUIC_INBOUND}" &&
  local NODE_REPLACE+="\"${NODE_NAME[13]} ${NODE_TAG[2]}\","

  [ -n "$PORT_SHADOWTLS" ] &&
  local SHADOWTLS_INBOUND=" { \"type\": \"shadowsocks\", \"tag\": \"${NODE_NAME[14]} ${NODE_TAG[3]}\", \"method\": \"$SHADOWTLS_METHOD\", \"password\": \"$SHADOWTLS_PASSWORD\", \"detour\": \"shadowtls-out\", \"udp_over_tcp\": false, \"multiplex\": { \"enabled\": true, \"protocol\": \"h2mux\", \"max_connections\": 8, \"min_streams\": 16, \"padding\": true, \"brutal\":{ \"enabled\":${IS_BRUTAL}, \"up_mbps\":1000, \"down_mbps\":1000 } } }, { \"type\": \"shadowtls\", \"tag\": \"shadowtls-out\", \"server\": \"${SERVER_IP}\", \"server_port\": ${PORT_SHADOWTLS}, \"version\": 3, \"password\": \"${UUID[14]}\", \"tls\": { \"enabled\": true, \"server_name\": \"${TLS_SERVER[14]}\", \"utls\": { \"enabled\": true, \"fingerprint\": \"firefox\" } } }," &&
  local OUTBOUND_REPLACE+="${SHADOWTLS_INBOUND}" &&
  local NODE_REPLACE+="\"${NODE_NAME[14]} ${NODE_TAG[3]}\","

  [ -n "$PORT_SHADOWSOCKS" ] &&
  local OUTBOUND_REPLACE+=" { \"type\": \"shadowsocks\", \"tag\": \"${NODE_NAME[15]} ${NODE_TAG[4]}\", \"server\": \"${SERVER_IP}\", \"server_port\": $PORT_SHADOWSOCKS, \"method\": \"${SHADOWSOCKS_METHOD}\", \"password\": \"${UUID[15]}\", \"multiplex\": { \"enabled\": true, \"protocol\": \"h2mux\", \"max_connections\": 8, \"min_streams\": 16, \"padding\": true, \"brutal\":{ \"enabled\":${IS_BRUTAL}, \"up_mbps\":1000, \"down_mbps\":1000 } } }," &&
  local NODE_REPLACE+="\"${NODE_NAME[15]} ${NODE_TAG[4]}\","

  [ -n "$PORT_TROJAN" ] &&
  local OUTBOUND_REPLACE+=" { \"type\": \"trojan\", \"tag\": \"${NODE_NAME[16]} ${NODE_TAG[5]}\", \"server\": \"${SERVER_IP}\", \"server_port\": $PORT_TROJAN, \"password\": \"$TROJAN_PASSWORD\", \"tls\": { \"enabled\": true, \"certificate_public_key_sha256\": [\"$SELF_SIGNED_FINGERPRINT_BASE64\"], \"server_name\":\"${TLS_SERVER_DEFAULT}\", \"utls\": { \"enabled\":true, \"fingerprint\":\"firefox\" } }, \"multiplex\": { \"enabled\":true, \"protocol\":\"h2mux\", \"max_connections\": 8, \"min_streams\": 16, \"padding\": true, \"brutal\":{ \"enabled\":${IS_BRUTAL}, \"up_mbps\":1000, \"down_mbps\":1000 } } }," &&
  local NODE_REPLACE+="\"${NODE_NAME[16]} ${NODE_TAG[5]}\","

  if [ -n "$PORT_VMESS_WS" ]; then
     if [[ "${STATUS[1]}" =~ $(text 27)|$(text 28) ]] || [[ "$IS_ARGO" = 'is_argo' && "$NONINTERACTIVE_INSTALL" = 'noninteractive_install' ]]; then
      local OUTBOUND_REPLACE+=" { \"type\": \"vmess\", \"tag\": \"${NODE_NAME[17]} ${NODE_TAG[6]}\", \"server\":\"${CDN[17]}\", \"server_port\":80, \"uuid\": \"${UUID[17]}\", \"security\": \"auto\", \"transport\": { \"type\":\"ws\", \"path\":\"/$VMESS_WS_PATH\", \"headers\": { \"Host\": \"$ARGO_DOMAIN\" } }, \"multiplex\": { \"enabled\":true, \"protocol\":\"h2mux\", \"max_streams\":16, \"padding\": true, \"brutal\":{ \"enabled\":${IS_BRUTAL}, \"up_mbps\":1000, \"down_mbps\":1000 } } },"
      [ "$ARGO_TYPE" = 'is_token_argo' ] && [ -z "$PROMPT" ] && local PROMPT="
  # $(text 94)"
    else
      local WS_SERVER_IP_SHOW=${WS_SERVER_IP[17]} &&
      local TYPE_HOST_DOMAIN=$VMESS_HOST_DOMAIN &&
      local TYPE_PORT_WS=$PORT_VMESS_WS &&
      local PROMPT+="
      # $(text 52)" &&
      local OUTBOUND_REPLACE+=" { \"type\": \"vmess\", \"tag\": \"${NODE_NAME[17]} ${NODE_TAG[6]}\", \"server\":\"${CDN[17]}\", \"server_port\":80, \"uuid\":\"${UUID[17]}\", \"security\": \"auto\", \"transport\": { \"type\":\"ws\", \"path\":\"/$VMESS_WS_PATH\", \"headers\": { \"Host\": \"$VMESS_HOST_DOMAIN\" } }, \"multiplex\": { \"enabled\":true, \"protocol\":\"h2mux\", \"max_streams\":16, \"padding\": true, \"brutal\":{ \"enabled\":${IS_BRUTAL}, \"up_mbps\":1000, \"down_mbps\":1000 } } },"
    fi
    local NODE_REPLACE+="\"${NODE_NAME[17]} ${NODE_TAG[6]}\","
  fi

  if [ -n "$PORT_VLESS_WS" ]; then
    if [[ "${STATUS[1]}" =~ $(text 27)|$(text 28) ]] || [[ "$IS_ARGO" = 'is_argo' && "$NONINTERACTIVE_INSTALL" = 'noninteractive_install' ]]; then
      local OUTBOUND_REPLACE+=" { \"type\": \"vless\", \"tag\": \"${NODE_NAME[18]} ${NODE_TAG[7]}\", \"server\":\"${CDN[18]}\", \"server_port\":443, \"uuid\": \"${UUID[18]}\", \"tls\": { \"enabled\":true, \"server_name\":\"$ARGO_DOMAIN\", \"insecure\": false, \"utls\": { \"enabled\":true, \"fingerprint\":\"firefox\" } }, \"transport\": { \"type\":\"ws\", \"path\":\"/$VLESS_WS_PATH\", \"headers\": { \"Host\": \"$ARGO_DOMAIN\" }, \"max_early_data\":2560, \"early_data_header_name\":\"Sec-WebSocket-Protocol\" }, \"multiplex\": { \"enabled\":true, \"protocol\":\"h2mux\", \"max_streams\":16, \"padding\": true, \"brutal\":{ \"enabled\":${IS_BRUTAL}, \"up_mbps\":1000, \"down_mbps\":1000 } } },"
      [ "$ARGO_TYPE" = 'is_token_argo' ] && [ -z "$PROMPT" ] && local PROMPT="
  # $(text 94)"
    else
      local WS_SERVER_IP_SHOW=${WS_SERVER_IP[18]} &&
      local TYPE_HOST_DOMAIN=$VLESS_HOST_DOMAIN &&
      local TYPE_PORT_WS=$PORT_VLESS_WS &&
      local PROMPT+="
      # $(text 52)" &&
      local OUTBOUND_REPLACE+=" { \"type\": \"vless\", \"tag\": \"${NODE_NAME[18]} ${NODE_TAG[7]}\", \"server\":\"${CDN[18]}\", \"server_port\":443, \"uuid\": \"${UUID[18]}\",\"tls\": { \"enabled\":true, \"server_name\":\"$VLESS_HOST_DOMAIN\", \"insecure\": false, \"utls\": { \"enabled\":true, \"fingerprint\":\"firefox\" } }, \"transport\": { \"type\":\"ws\", \"path\":\"/$VLESS_WS_PATH\", \"headers\": { \"Host\": \"$VLESS_HOST_DOMAIN\" }, \"max_early_data\":2560, \"early_data_header_name\":\"Sec-WebSocket-Protocol\" }, \"multiplex\": { \"enabled\":true, \"protocol\":\"h2mux\", \"max_streams\":16, \"padding\": true, \"brutal\":{ \"enabled\":${IS_BRUTAL}, \"up_mbps\":1000, \"down_mbps\":1000 } } },"
    fi
    local NODE_REPLACE+="\"${NODE_NAME[18]} ${NODE_TAG[7]}\","
  fi

  [ -n "$PORT_H2_REALITY" ] &&
  local REALITY_H2_INBOUND=" { \"type\": \"vless\", \"tag\": \"${NODE_NAME[19]} ${NODE_TAG[8]}\", \"server\": \"${SERVER_IP}\", \"server_port\": ${PORT_H2_REALITY}, \"uuid\":\"${UUID[19]}\", \"tls\": { \"enabled\":true, \"server_name\":\"${TLS_SERVER[19]}\", \"utls\": { \"enabled\":true, \"fingerprint\":\"firefox\" }, \"reality\":{ \"enabled\":true, \"public_key\":\"${REALITY_PUBLIC[19]}\", \"short_id\":\"\" } }, \"transport\": { \"type\": \"http\" } }," &&
  local REALITY_H2_NODE="\"${NODE_NAME[19]} ${NODE_TAG[8]}\"" &&
  local NODE_REPLACE+="${REALITY_H2_NODE}," &&
  local OUTBOUND_REPLACE+=" ${REALITY_H2_INBOUND}"

  [ -n "$PORT_GRPC_REALITY" ] &&
  local OUTBOUND_REPLACE+=" { \"type\": \"vless\", \"tag\": \"${NODE_NAME[20]} ${NODE_TAG[9]}\", \"server\": \"${SERVER_IP}\", \"server_port\": ${PORT_GRPC_REALITY}, \"uuid\":\"${UUID[20]}\", \"tls\": { \"enabled\":true, \"server_name\":\"${TLS_SERVER[20]}\", \"utls\": { \"enabled\":true, \"fingerprint\":\"firefox\" }, \"reality\":{ \"enabled\":true, \"public_key\":\"${REALITY_PUBLIC[20]}\", \"short_id\":\"\" } }, \"transport\": { \"type\": \"grpc\", \"service_name\": \"grpc\" } }," &&
  local NODE_REPLACE+="\"${NODE_NAME[20]} ${NODE_TAG[9]}\","

  [ -n "$PORT_ANYTLS" ] &&
  local OUTBOUND_REPLACE+=" { \"type\": \"anytls\", \"tag\": \"${NODE_NAME[21]} ${NODE_TAG[10]}\", \"server\": \"${SERVER_IP}\", \"server_port\": ${PORT_ANYTLS}, \"password\": \"${UUID[21]}\", \"idle_session_check_interval\": \"30s\", \"idle_session_timeout\": \"30s\", \"min_idle_session\": 5, \"tls\": { \"enabled\": true, \"certificate_public_key_sha256\": [\"$SELF_SIGNED_FINGERPRINT_BASE64\"], \"server_name\": \"${TLS_SERVER_DEFAULT}\", \"utls\": { \"enabled\": true, \"fingerprint\": \"firefox\" } } }," &&
  local NODE_REPLACE+="\"${NODE_NAME[21]} ${NODE_TAG[10]}\","

  {
    # sing-box SFM SFA 模板
    local SING_BOX_JSON=$(wget --no-check-certificate -qO- --tries=3 --timeout=2 ${GH_PROXY}${SUBSCRIBE_TEMPLATE}/sing-box)
    echo $SING_BOX_JSON | sed "s#\"<OUTBOUND_REPLACE>\",#$OUTBOUND_REPLACE#; s#\"<NODE_REPLACE>\"#${NODE_REPLACE%,}#g" | ${WORK_DIR}/jq > ${WORK_DIR}/subscribe/sing-box
  } &>/dev/null

  # 生成二维码 url 文件
  [ "$IS_SUB" = 'is_sub' ] && cat > ${WORK_DIR}/subscribe/qr << EOF
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
$(${WORK_DIR}/qrencode "$SUBSCRIBE_ADDRESS/${UUID_CONFIRM}/auto")

$(text 82) 2:
$(${WORK_DIR}/qrencode "$SUBSCRIBE_ADDRESS/${UUID_CONFIRM}/auto2")
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
│   $(warning "Clash Verge")  │
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

$(info "$(echo "{ \"outbounds\":[ ${OUTBOUND_REPLACE%,} ] }" | ${WORK_DIR}/jq)

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

SFI / SFA / SFM $(text 80):
$SUBSCRIBE_ADDRESS/${UUID_CONFIRM}/sing-box

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
$(${WORK_DIR}/qrencode $SUBSCRIBE_ADDRESS/${UUID_CONFIRM}/auto)

$(hint "$(text 82) 2:")
$(${WORK_DIR}/qrencode $SUBSCRIBE_ADDRESS/${UUID_CONFIRM}/auto2)
"

  # 生成并显示节点信息
  echo "$EXPORT_LIST_FILE" > ${WORK_DIR}/list
  cat ${WORK_DIR}/list

  # 显示脚本使用情况数据
  statistics_of_run-times get
}

# 创建快捷方式
create_shortcut() {
  cat > ${WORK_DIR}/sb.sh << EOF
#!/usr/bin/env bash

bash <(wget --no-check-certificate -qO- https://raw.githubusercontent.com/fscarmen/sing-box/main/sing-box.sh) \$1
EOF
  chmod +x ${WORK_DIR}/sb.sh
  ln -sf ${WORK_DIR}/sb.sh /usr/bin/sb
  [ -s /usr/bin/sb ] && info "\n $(text 71) "
}

# 更换各协议的监听端口
change_start_port() {
  OLD_PORTS=$(awk -F ':|,' '/listen_port/{print $2}' ${WORK_DIR}/conf/*)
  OLD_START_PORT=$(awk 'NR == 1 { min = $0 } { if ($0 < min) min = $0; count++ } END {print min}' <<< "$OLD_PORTS")
  OLD_CONSECUTIVE_PORTS=$(awk 'END { print NR }' <<< "$OLD_PORTS")
  input_start_port $OLD_CONSECUTIVE_PORTS
  cmd_systemctl disable sing-box
  for ((a=0; a<$OLD_CONSECUTIVE_PORTS; a++)) do
    [ -s ${WORK_DIR}/conf/${CONF_FILES[a]} ] && sed -i "s/\(.*listen_port.*:\)$((OLD_START_PORT+a))/\1$((START_PORT+a))/" ${WORK_DIR}/conf/*
  done
  fetch_nodes_value
  [ -n "$PORT_NGINX" ] && UUID_CONFIRM=$(sed -n 's#.*location[ ]\+\/\(.*\)-v[ml]ess.*#\1#gp' /etc/sing-box/nginx.conf | sed -n '1p') && export_nginx_conf_file
  cmd_systemctl enable sing-box
  [ -n "$ARGO_DOMAIN" ] && export_argo_json_file
  sleep 2
  export_list
  cmd_systemctl status sing-box &>/dev/null && info " Sing-box $(text 30) $(text 37) " || error " Sing-box $(text 30) $(text 38) "
}

# 增加或删除协议
change_protocols() {
  check_install
  [ "${STATUS[0]}" = "$(text 26)" ] && error "\n Sing-box $(text 26) "

  # 检查服务器 IP
  check_system_ip

  # 查找已安装的协议，并遍历其在所有协议列表中的名称，获取协议名后存放在 EXISTED_PROTOCOLS; 没有的协议存放在 NOT_EXISTED_PROTOCOLS
  INSTALLED_PROTOCOLS_LIST=$(awk -F '"' '/"tag":/{print $4}' ${WORK_DIR}/conf/*_inbounds.json | grep -v 'shadowtls-in' | awk '{print $NF}')
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
    rm -f ${WORK_DIR}/conf/*${t}
  done

  # 寻找已存在协议中原有的端口号
  for p in "${KEEP_PROTOCOLS[@]}"; do
    for u in "${!PROTOCOL_LIST[@]}"; do
      [ "$p" = "${PROTOCOL_LIST[u]}" ] && KEEP_PORTS+=("$(awk -F '[:,]' '/listen_port/{print $2}' ${WORK_DIR}/conf/*${NODE_TAG[u]}_inbounds.json)")
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
    NEED_PRIVATE_KEY='need_private_key'
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
  if [ -s ${ARGO_DAEMON_FILE} ]; then
    local ARGO_ORIGIN_RULES_STATUS=is_argo
    [ "$SYSTEM" = 'Alpine' ] && ARGO_RUNS="$(sed -n 's/command="\(.*\)"/\1/gp' $ARGO_DAEMON_FILE) $(sed -n 's/command_args="\(.*\)"/\1/gp' $ARGO_DAEMON_FILE)" || ARGO_RUNS=$(sed -n "s/^ExecStart=\(.*\)/\1/gp" ${ARGO_DAEMON_FILE})
  elif ls ${WORK_DIR}/conf/*-ws*inbounds.json >/dev/null 2>&1; then
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

  # 如之前没有 ws，现新增的 ws，则确认服务器 IP 和输入 cdn
  if [[ "${#CDN[@]}" = '0' && ( "$ARGO_READY" = 'argo_ready' || "$ORIGIN_READY" = 'origin_ready' ) ]]; then
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

    # 输入服务器 IP,默认为检测到的服务器 IP，如果全部为空，则提示并退出脚本
    [ -z "$SERVER_IP" ] && reading "\n $(text 10) " SERVER_IP
    SERVER_IP=${SERVER_IP:-"$SERVER_IP_DEFAULT"} && WS_SERVER_IP_SHOW=$SERVER_IP
    [ -z "$SERVER_IP" ] && error " $(text 47) "

    input_cdn
  fi

  # 获取 H2 + Reality 端口
  CHECK_PROTOCOLS=$(asc "$CHECK_PROTOCOLS" ++)
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    POSITION=$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")
    PORT_H2_REALITY=${REINSTALL_PORTS[POSITION]}
    NEED_PRIVATE_KEY='need_private_key'
  else
    unset PORT_H2_REALITY
  fi

  # 获取 gRPC + Reality 端口
  CHECK_PROTOCOLS=$(asc "$CHECK_PROTOCOLS" ++)
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    POSITION=$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")
    PORT_GRPC_REALITY=${REINSTALL_PORTS[POSITION]}
    NEED_PRIVATE_KEY='need_private_key'
  else
    unset PORT_GRPC_REALITY
  fi

  # 如之前没有 Reality，现新增的 reality，则确认 privateKey
  [[ "${#REALITY_PRIVATE[@]}" = 0 && "${NEED_PRIVATE_KEY}" = 'need_private_key' ]] && input_reality_key

  # 获取 anytls 端口
  CHECK_PROTOCOLS=$(asc "$CHECK_PROTOCOLS" ++)
  if [[ "${INSTALL_PROTOCOLS[@]}" =~ "$CHECK_PROTOCOLS" ]]; then
    POSITION=$(awk -v target=$CHECK_PROTOCOLS '{ for(i=1; i<=NF; i++) if($i == target) { print i-1; break } }' <<< "${INSTALL_PROTOCOLS[*]}")
    PORT_ANYTLS=${REINSTALL_PORTS[POSITION]}
  else
    unset PORT_ANYTLS
  fi

  # 停止 sing-box 服务
  cmd_systemctl disable sing-box

  # 关闭防火墙相关端口
  [ "$SYSTEM" = 'CentOS' ] && firewall_configuration close

  # 生成 Nginx 配置文件
  [ -n "$PORT_NGINX" ] && export_nginx_conf_file

  # 重新生成 Sing-box 守护进程文件
  sing-box_systemd

  # 生成各协议的 json 文件
  sing-box_json change

  # 如有需要，安装和删除 Argo 服务
  if ls ${WORK_DIR}/conf/*-ws*inbounds.json >/dev/null 2>&1; then
    if [[ "$ARGO_OR_ORIGIN_RULES" != '2' && "$ARGO_ORIGIN_RULES_STATUS" != 'is_origin' && ! -s ${ARGO_DAEMON_FILE} ]]; then
      argo_systemd
      cmd_systemctl enable argo >/dev/null 2>&1
    fi
  elif [ -s ${ARGO_DAEMON_FILE} ]; then
    cmd_systemctl disable argo >/dev/null 2>&1
    rm -f ${ARGO_DAEMON_FILE}
    [ -s ${WORK_DIR}/tunnel.json ] && rm -f ${WORK_DIR}/tunnel.*
  fi

  # 如有需要，删除 nginx 配置文件
  ! ls ${ARGO_DAEMON_FILE} >/dev/null 2>&1 && [[ -s ${WORK_DIR}/nginx.conf && "$IS_SUB" = 'no_sub' ]] && IS_ARGO=no_argo && rm -f ${WORK_DIR}/nginx.conf

  # 运行 sing-box
  cmd_systemctl enable sing-box

  # 打开防火墙相关端口
  [ "$SYSTEM" = 'CentOS' ] && firewall_configuration open

  # 等待服务启动
  sleep 3

  # 再次检测状态，运行 sing-box
  check_install
  case "${STATUS[0]}" in
    "$(text 26)" )
      error "\n Sing-box $(text 28) $(text 38) \n"
      ;;
    "$(text 27)" )
      cmd_systemctl enable sing-box
      cmd_systemctl status sing-box &>/dev/null && info "\n Sing-box $(text 28) $(text 37) \n" || error "\n Sing-box $(text 28) $(text 38) \n"
      ;;
    "$(text 28)" )
      info "\n Sing-box $(text 28) $(text 37) \n"
  esac

  # 导出节点和订阅服务信息
  export_list
}

# 卸载 sing-box 全家桶
uninstall() {
  if [ -d ${WORK_DIR} ]; then
    [ -s ${ARGO_DAEMON_FILE} ] && cmd_systemctl disable argo &>/dev/null
    [ -s ${SINGBOX_DAEMON_FILE} ] && cmd_systemctl disable sing-box &>/dev/null
    sleep 1
    [[ -s ${WORK_DIR}/nginx.conf && "$(ps -ef | grep -c '[n]ginx')" = 0 ]] && reading "\n $(text 83) " REMOVE_NGINX
    [ "${REMOVE_NGINX,,}" = 'y' ] && ${PACKAGE_UNINSTALL[int]} nginx >/dev/null 2>&1
    [ "$IS_HOPPING" = 'is_hopping' ] && del_port_hopping_nat
    [ "$SYSTEM" = 'CentOS' ] && firewall_configuration close
    rm -rf ${WORK_DIR} ${TEMP_DIR} ${ARGO_DAEMON_FILE} ${SINGBOX_DAEMON_FILE} /usr/bin/sb
    info "\n $(text 16) \n"
  else
    error "\n $(text 15) \n"
  fi
}


# Sing-box 的最新版本
version() {
  # 获取需要下载的 sing-box 版本
  local ONLINE=$(get_sing_box_version)

  grep -q '.' <<< "$ONLINE" || error " $(text 100) \n"
  local LOCAL=$(${WORK_DIR}/sing-box version | awk '/version/{print $NF}')
  info "\n $(text 40) "
  [[ -n "$ONLINE" && "$ONLINE" != "$LOCAL" ]] && reading "\n $(text 9) " UPDATE || info " $(text 41) "

  if [ "${UPDATE,,}" = 'y' ]; then
    check_system_info
    wget --no-check-certificate --continue ${GH_PROXY}https://github.com/SagerNet/sing-box/releases/download/v$ONLINE/sing-box-$ONLINE-linux-$SING_BOX_ARCH.tar.gz -qO- | tar xz -C $TEMP_DIR sing-box-$ONLINE-linux-$SING_BOX_ARCH/sing-box

    if [ -s $TEMP_DIR/sing-box-$ONLINE-linux-$SING_BOX_ARCH/sing-box ]; then
      cmd_systemctl disable sing-box

      # 备份旧版本
      cp ${WORK_DIR}/sing-box ${WORK_DIR}/sing-box.bak
      hint "\n $(text 102) \n"

      # 安装新版本
      chmod +x $TEMP_DIR/sing-box-$ONLINE-linux-$SING_BOX_ARCH/sing-box && mv $TEMP_DIR/sing-box-$ONLINE-linux-$SING_BOX_ARCH/sing-box ${WORK_DIR}/sing-box
      cmd_systemctl enable sing-box
      sleep 2

      # 检查新版本是否成功运行
      if cmd_systemctl status sing-box &>/dev/null; then
        # 新版本运行成功，删除备份
        rm -f ${WORK_DIR}/sing-box.bak
        info "\n $(text 103) \n"
      else
        # 新版本运行失败，恢复旧版本
        warning "\n $(text 104) \n"
        mv ${WORK_DIR}/sing-box.bak ${WORK_DIR}/sing-box
        cmd_systemctl enable sing-box
        sleep 2

        if cmd_systemctl status sing-box &>/dev/null; then
          info "\n $(text 105) \n"
        else
          error "\n $(text 106) \n"
        fi
      fi
    else
      error "\n $(text 42) "
    fi
  fi
}

# 判断当前 Sing-box 的运行状态，并对应的给菜单和动作赋值
menu_setting() {
  if [[ "${STATUS[0]}" =~ $(text 27)|$(text 28) ]]; then
    OPTION[1]="1 .  $(text 29)"
    [ "${STATUS[0]}" = "$(text 28)" ] && OPTION[2]="2 .  $(text 27) Sing-box (sb -s)" || OPTION[2]="2 .  $(text 28) Sing-box (sb -s)"
    [ "${STATUS[1]}" = "$(text 28)" ] && OPTION[3]="3 .  $(text 27) Argo (sb -a)" || OPTION[3]="3 .  $(text 28) Argo (sb -a)"
    OPTION[4]="4 .  $(text 92)"
    OPTION[5]="5 .  $(text 30)"
    OPTION[6]="6 .  $(text 31)"
    OPTION[7]="7 .  $(text 32)"
    OPTION[8]="8 .  $(text 62)"
    OPTION[9]="9.   $(text 121)"
    OPTION[10]="10.  $(text 33)"
    OPTION[11]="11.  $(text 59)"
    OPTION[12]="12.  $(text 69)"
    OPTION[13]="13.  $(text 76)"

    ACTION[1]() { export_list; exit 0; }

    [ "${STATUS[0]}" = "$(text 28)" ] &&
    ACTION[2]() {
      cmd_systemctl disable sing-box
      cmd_systemctl status sing-box &>/dev/null && error " Sing-box $(text 27) $(text 38) " || info " Sing-box $(text 27) $(text 37)"
    } ||
    ACTION[2]() {
      cmd_systemctl enable sing-box
      sleep 2
      cmd_systemctl status sing-box &>/dev/null && info " Sing-box $(text 28) $(text 37)" || error " Sing-box $(text 28) $(text 38) "
    }

    [ "${STATUS[1]}" = "$(text 28)" ] &&
    ACTION[3]() {
      cmd_systemctl disable argo
      cmd_systemctl status argo &>/dev/null && error " Argo $(text 27) $(text 38) " || info " Argo $(text 27) $(text 37)"
    } ||
    ACTION[3]() {
      cmd_systemctl enable argo
      sleep 2
      cmd_systemctl status argo &>/dev/null &&  info " Argo $(text 28) $(text 37)" || error " Argo $(text 28) $(text 38) "
      grep -qs '\--url' ${ARGO_DAEMON_FILE} && fetch_quicktunnel_domain && export_list
    }

    ACTION[4]() { change_argo; exit; }
    ACTION[5]() { change_start_port; exit; }
    ACTION[6]() { version; exit; }
    ACTION[7]() { bash <(wget --no-check-certificate -qO- ${GH_PROXY}https://raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master/tcp.sh); exit; }
    ACTION[8]() { change_protocols; exit; }
    ACTION[9]() { change_cdn; exit; }
    ACTION[10]() { uninstall; exit; }
    ACTION[11]() { bash <(wget --no-check-certificate -qO- ${GH_PROXY}https://raw.githubusercontent.com/fscarmen/argox/main/argox.sh) -$L; exit; }
    ACTION[12]() { bash <(wget --no-check-certificate -qO- ${GH_PROXY}https://raw.githubusercontent.com/fscarmen/sba/main/sba.sh) -$L; exit; }
    ACTION[13]() { bash <(wget --no-check-certificate -qO- https://tcp.hy2.sh/); exit; }
  else
    OPTION[1]="1.  $(text 115)"
    OPTION[2]="2.  $(text 34) + Argo + $(text 80) $(text 89)"
    OPTION[3]="3.  $(text 34) + Argo $(text 89)"
    OPTION[4]="4.  $(text 34) + $(text 80) $(text 89)"
    OPTION[5]="5.  $(text 34)"
    OPTION[6]="6.  $(text 32)"
    OPTION[7]="7.  $(text 59)"
    OPTION[8]="8.  $(text 69)"
    OPTION[9]="9.  $(text 76)"

    ACTION[1]() { IS_FAST_INSTALL='is_fast_install'; CHOOSE_PROTOCOLS=${CHOOSE_PROTOCOLS:-'a'}; START_PORT=${START_PORT:-"$START_PORT_DEFAULT"}; CDN=${CDN:-"${CDN_DOMAIN[0]}"}; IS_SUB='is_sub'; IS_ARGO='is_argo'; PORT_HOPPING_RANGE=${PORT_HOPPING_RANGE:-'50000:51000'}; install_sing-box; export_list install; create_shortcut; exit; }
    ACTION[2]() { IS_SUB=is_sub; IS_ARGO=is_argo; install_sing-box; export_list install; create_shortcut; exit; }
    ACTION[3]() { IS_SUB=no_sub; IS_ARGO=is_argo; install_sing-box; export_list install; create_shortcut; exit; }
    ACTION[4]() { IS_SUB=is_sub; IS_ARGO=no_argo; install_sing-box; export_list install; create_shortcut; exit; }
    ACTION[5]() { install_sing-box; export_list install; create_shortcut; exit; }
    ACTION[6]() { bash <(wget --no-check-certificate -qO- ${GH_PROXY}https://raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master/tcp.sh); exit; }
    ACTION[7]() { bash <(wget --no-check-certificate -qO- ${GH_PROXY}https://raw.githubusercontent.com/fscarmen/argox/main/argox.sh) -$L; exit; }
    ACTION[8]() { bash <(wget --no-check-certificate -qO- ${GH_PROXY}https://raw.githubusercontent.com/fscarmen/sba/main/sba.sh) -$L; exit; }
    ACTION[9]() { bash <(wget --no-check-certificate -qO- ${GH_PROXY}https://tcp.hy2.sh/); exit; }
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
  info "\t Sing-box: ${STATUS[0]}\t $SING_BOX_VERSION\t\t $SING_BOX_MEMORY_USAGE\n\t Argo: ${STATUS[1]}\t $ARGO_VERSION\t\t $ARGO_MEMORY_USAGE\n \t Nginx: ${STATUS[2]}\t $NGINX_VERSION\t $NGINX_MEMORY_USAGE "
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
statistics_of_run-times update sing-box.sh 2>/dev/null

# 传参
[[ "${*^^}" =~ '-E'|'-K' ]] && L=E
[[ "${*^^}" =~ '-C'|'-B'|'-L' ]] && L=C

# 获取 -F 参数的值
CONFIG_FILE=$(awk '-F[ =]' 'tolower($1) ~ /^-f$/{print $2}' <<< "$*")
if [[ -n "$CONFIG_FILE" && -s "$CONFIG_FILE" ]]; then
  NONINTERACTIVE_INSTALL=noninteractive_install
  . $CONFIG_FILE
  L=${LANGUAGE^^}
  [ "$ARGO" = 'true' ] && IS_ARGO=is_argo || IS_ARGO=no_argo
  [ "$SUBSCRIBE" = 'true' ] && IS_SUB=is_sub || IS_SUB=no_sub
fi

select_language
check_system_info
check_brutal

# 可以是 Key Value 或者 Key=Value 的形式。传参时，
# 传参处理1: 把所有的 = 变为空格，但保留 =" ，因为 Json TunnelSecret 是 =" 结尾的，如 {"AccountTag":"9cc9e3e4d8f29d2a02e297f14f20513a","TunnelSecret":"6AYfKBOoNlPiTAuWg64ZwujsNuERpWLm6pPJ2qpN8PM=","TunnelID":"1ac55430-f4dc-47d5-a850-bdce824c4101"}
# 传参处理2: 去掉 sudo cloudflared service install ，以方便用户输入 Token 并能正确读取真正的以 ey 开头的 Value
ALL_PARAMETER=($(sed -E 's/(-c|-e|-f|-C|-E|-F) //; s/=([^"])/ \1/g; s/sudo cloudflared service install //' <<< $*))
[[ "${#ALL_PARAMETER[@]}" > 11 && "${ALL_PARAMETER[@]^^}" == *"--LANGUAGE"* && "${ALL_PARAMETER[@]^^}" == *"--CHOOSE_PROTOCOLS"* && "${ALL_PARAMETER[@]^^}" == *"--START_PORT"* && "${ALL_PARAMETER[@]^^}" == *"--SERVER_IP"* && "${ALL_PARAMETER[@]^^}" == *"--UUID"* && "${ALL_PARAMETER[@]^^}" == *"--NODE_NAME"* ]] && NONINTERACTIVE_INSTALL=noninteractive_install

# 传参处理，无交互快速安装参数
for z in ${!ALL_PARAMETER[@]}; do
  case "${ALL_PARAMETER[z]^^}" in
    -K|-L )
      ((z++))
      IS_FAST_INSTALL=is_fast_install
      ;;
    -P )
      ((z++)); START_PORT=${ALL_PARAMETER[z]}; check_install; [ "${STATUS[0]}" = "$(text 26)" ] && error "\n Sing-box $(text 26) "; change_start_port; exit 0
      ;;
    -S )
      check_install
      if [ "${STATUS[0]}" = "$(text 26)" ]; then
        error "\n Sing-box $(text 26) "
      elif [ "${STATUS[0]}" = "$(text 28)" ]; then
        cmd_systemctl disable sing-box
        cmd_systemctl status sing-box &>/dev/null && error " Sing-box $(text 27) $(text 38) " || info "\n Sing-box $(text 27) $(text 37)"
      elif [ "${STATUS[0]}" = "$(text 27)" ]; then
        cmd_systemctl enable sing-box
        sleep 2
        cmd_systemctl status sing-box &>/dev/null && info "\n Sing-box $(text 28) $(text 37)" || error "\n Sing-box $(text 28) $(text 38)"
      fi
      exit 0
      ;;
    -A )
      check_install
      if [ "${STATUS[1]}" = "$(text 26)" ]; then
        error "\n Argo $(text 26) "
      elif [ "${STATUS[1]}" = "$(text 28)" ]; then
        cmd_systemctl disable argo
        cmd_systemctl status argo &>/dev/null && error " Argo $(text 27) $(text 38) " || info "\n Argo $(text 27) $(text 37)"
      elif [ "${STATUS[1]}" = "$(text 27)" ]; then
        cmd_systemctl enable argo
        sleep 2
        cmd_systemctl status argo &>/dev/null && info "\n Argo $(text 28) $(text 37)" || error "\n Argo $(text 28) $(text 38) "
        grep -qs '\--url' ${ARGO_DAEMON_FILE} && fetch_quicktunnel_domain && export_list
      fi
      exit 0
      ;;
    -T )
      change_argo; exit 0
      ;;
    -D )
      change_cdn; exit 0
      ;;
    -U )
      check_install; uninstall; exit 0
      ;;
    -N )
      [ ! -s ${WORK_DIR}/list ] && error " Sing-box $(text 26) "; export_list; exit 0
      ;;
    -V )
      check_system_info; check_arch; version; exit 0
      ;;
    -B )
      bash <(wget --no-check-certificate -qO- ${GH_PROXY}https://raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master/tcp.sh); exit
      ;;
    -R )
      change_protocols; exit 0
      ;;
    --LANGUAGE )
      ((z++)); [[ "${ALL_PARAMETER[z]^^}" =~ ^C ]] && LANGUAGE=C || LANGUAGE=E
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
    --REALITY_PRIVATE )
      ((z++)); REALITY_PRIVATE=${ALL_PARAMETER[z]}
      ;;
  esac
done

check_root
check_arch
check_dependencies
check_system_ip
check_install
if [ "$NONINTERACTIVE_INSTALL" = 'noninteractive_install' ]; then
  # 预设默认值
  IS_SUB=${IS_SUB:-'no_sub'}
  IS_ARGO=${IS_ARGO:-'no_argo'}
  IS_HOPPING=${IS_HOPPING:-'no_hopping'}

  install_sing-box
  export_list install
  create_shortcut
elif [ "$IS_FAST_INSTALL" = 'is_fast_install' ]; then
  # 预设默认值
  CHOOSE_PROTOCOLS=${CHOOSE_PROTOCOLS:-'a'}
  START_PORT=${START_PORT:-"$START_PORT_DEFAULT"}
  CDN=${CDN:-"${CDN_DOMAIN[0]}"}
  IS_SUB='is_sub'
  IS_ARGO='is_argo'
  [[ "$PORT_HOPPING_RANGE" =~ ^[0-9]+:[0-9]+$ ]] && IS_HOPPING='is_hopping' || IS_HOPPING='no_hopping'

  install_sing-box
  export_list install
  create_shortcut
else
  menu_setting
  menu
fi