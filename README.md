# 【Sing-box 全家桶】

* * *

# 目录

- [1.更新信息](README.md#1更新信息)
- [2.项目特点](README.md#2项目特点)
- [3.Sing-box for VPS 运行脚本](README.md#3sing-box-for-vps-运行脚本)
- [4.无交互极速安装](README.md#4无交互极速安装)
- [5.Token Argo Tunnel 方案设置任意端口回源以使用 cdn](README.md#5token-argo-tunnel-方案设置任意端口回源以使用-cdn)
- [6.Vmess / Vless 方案设置任意端口回源以使用 cdn](README.md#6vmess--vless-方案设置任意端口回源以使用-cdn)
- [7.Docker 和 Docker compose 安装](README.md#7docker-和-docker-compose-安装)
- [8.Nekobox 设置 shadowTLS 方法](README.md#8nekobox-设置-shadowtls-方法)
- [9.主体目录文件及说明](README.md#9主体目录文件及说明)
- [10.鸣谢下列作者的文章和项目](README.md#10鸣谢下列作者的文章和项目)
- [11.免责声明](README.md#11免责声明)


* * *
## 1.更新信息
2024.04.16 v1.2.1 1. Fix the bug of dynamically adding and removing protocols; 2. CentOS 7 add EPEL to install nginx; 1. 修复动态增加和删除协议的 bug; 2. CentOS 7 增加 EPEL 软件仓库，以便安装 Nginx

2024.04.12 v1.2.0 1. Add Cloudflare Argo Tunnel, so that 10 protocols, including the transport mode of ws, no longer need to bring our own domain; 2. Cloudflare Argo Tunnel supports try, Json and Token methods. Use of [sb -t] online switching; 3. Cloudflare Argo Tunnel switch is [sb -a], and the Sing-box switch is changed from [sb -o] to [sb -s]; 4. If Json or Token Argo is used, the subscription address is the domain name; 5. For details: https://github.com/fscarmen/sing-box; 1. 增加 Cloudflare Argo Tunnel，让包括传输方式为ws在内的10个协议均不再需要自带域名; 2. Cloudflare Argo Tunnel 支持临时、Json 和 Token 方式，支持使用 [sb -t] 在线切换; 3.  Cloudflare Argo Tunnel 开关为 [sb -a]，Sing-box 开关从 [sb -o] 更换为 [sb -s]; 4. 若使用 Json 或者 Token 固定域名 Argo，则订阅地址则使用该域名; 5. 详细参考: https://github.com/fscarmen/sing-box

2024.04.01 sing-box + argo container version is newly launched, for details: https://github.com/fscarmen/sing-box; sing-box 全家桶 + argo 容器版本全新上线，详细参考: https://github.com/fscarmen/sing-box

<details>
    <summary>历史更新 history（点击即可展开或收起）</summary>
<br>

>2024.03.27 v1.1.11 Add two non-interactive installation modes: 1. pass parameter; 2.kv file, for details: https://github.com/fscarmen/sing-box; 增加两个的无交互安装模式: 1. 传参；2.kv 文件，详细参考: https://github.com/fscarmen/sing-box
>
>2024.03.26 v1.1.10 Thanks to UUb for the official change of the compilation, dependencies jq, qrencode from apt installation to download the binary file, reduce the installation time of about 15 seconds, the implementation of the project's positioning of lightweight, as far as possible to install the least system dependencies; 感谢 UUb 兄弟的官改编译，依赖 jq, qrencode 从 apt 安装改为下载二进制文件，缩减安装时间约15秒，贯彻项目轻量化的定位，尽最大可能安装最少的系统依赖
>
>2024.03.22 v1.1.9 1. In the Sing-box client, add the brutal field in the TCP protocol to make it effective; 2. Compatible with CentOS 7,8,9; 3. Remove default Github CDN; 1. 在 Sing-box 客户端，TCP 协议协议里加上 brutal 字段以生效; 2. 适配 CentOS 7,8,9; 3. 去掉默认的 Github 加速网
>
>2024.3.18 v1.1.8 Move nginx for subscription services to the systemd daemon, following sing-box startup and shutdown; 把用于订阅服务的 nginx 移到 systemd daemon，跟随 sing-box 启停
>
>2024.3.13 v1.1.7 Subscription made optional, no nginx and qrcode installed if not needed; 在线订阅改为可选项，如不需要，不安装 nginx 和 qrcode
>
>2024.3.11 v1.1.6 1. Subscription api too many problems not working properly, instead put template-2 on Github; 2. Use native IP if it supports unlocking chatGPT, otherwise use warp chained proxy unlocking; 1. 在线转订阅 api 太多问题不能正常使用，改为把模板2放Github; 2. 如自身支持解锁 chatGPT，则使用原生 IP，否则使用 warp 链式代理解锁
>
>2024.3.10 v1.1.5 1. To protect node data security, use fake information to fetch subscribe api; 2. Adaptive the above clients. http://\<server ip\>:\<nginx port\>/\<uuid\>/<uuid>/<auto | auto2>; 1. 为保护节点数据安全，在 api 转订阅时，使用虚假信息; 2. 自适应以上的客户端，http://\<server ip\>:\<nginx port\>/\<uuid\>/<auto | auto2>
>
>2024.3.4 v1.1.4 1. Support V2rayN / Nekobox / Clash / sing-box / Shadowrocket subscribe. http://\<server ip\>:\<nginx port\>/\<uuid\>/\<qr | clash | neko | proxies | shadowrocket | sing-box-pc | sing-box-phone | v2rayn\>. Index of all subscribes: http://\<server ip\>:\<nginx port\>/\<uuid\>/  . Reinstall is required; 2. Adaptive the above clients. http://\<server ip\>:\<nginx port\>/\<uuid\>/auto ; 1. 增加 V2rayN / Nekobox / Clash / sing-box / Shadowrocket 订阅，http://\<server ip\>:\<nginx port\>/\<uuid\>/\<qr | clash | neko | proxies | shadowrocket | sing-box-pc | sing-box-phone | v2rayn\>， 所有订阅的索引: http://\<server ip\>:\<nginx port\>/\<uuid\>/，需要重新安装; 2. 自适应以上的客户端，http://\<server ip\>:\<nginx port\>/\<uuid\>/auto
>
>2024.2.16 v1.1.3 1. Support v2rayN V6.33 Tuic and Hysteria2 protocol URLs; 2. Add DNS module to adapt Sing-box V1.9.0-alpha.8; 3. Reconstruct the installation protocol, add delete protocols and protocol export module, each parameter is more refined. ( Reinstall is required ); 4. Remove obfs obfuscation from Hysteria2; 1. 支持 v2rayN V6.33 Tuic 和 Hysteria2 协议 URL; 2. 增加 DNS 模块以适配 Sing-box V1.9.0-alpha.8; 3. 重构安装协议，增加删除协议及协议输出模块，各参数更精细 (需要重新安装); 4. 去掉 Hysteria2 的 obfs 混淆
>
>2023.12.25 v1.1.2 1. support Sing-box 1.8.0 latest Rule Set and Experimental; 2. api.openai.com routes to WARP IPv4, other openai websites routes to WARP IPv6; 3. Start port changes to 100; 1. 支持 Sing-box 1.8.0 最新的 Rule Set 和 Experimental; 2. api.openai.com 分流到 WARP IPv4， 其他 openai 网站分流到 WARP IPv6; 3. 开始端口改为 100
>
>2023.11.21 v1.1.1 1. XTLS + REALITY remove flow: xtls-reality-vision to support multiplexing and TCP brutal (requires reinstallation); 2. Clash meta add multiplexing parameter. 1. XTLS + REALITY 去掉 xtls-reality-vision 流控以支持多路复用和 TCP brutal (需要重新安装); 2. Clash meta 增加多路复用参数
>
>2023.11.17 v1.1.0 1. Add [ H2 + Reality ] and [ gRPC + Reality ]. Reinstall is required; 2. Use beta verion instead of alpha; 3. Support TCP brutal and add the official install script; 1. 增加 [ H2 + Reality ] 和 [ gRPC + Reality ]，需要重新安装; 2. 由于 Sing-box 更新极快，将使用 beta 版本替代 alpha 3. 支持 TCP brutal，并提供官方安装脚本
>
>2023.11.15 v1.0.1 1. Support TCP brutal. Reinstall is required; 2. Use alpha verion instead of latest; 3. Change the default CDN to [ cn.azhz.eu.org ]; 1. 支持 TCP brutal，需要重新安装; 2. 由于 Sing-box 更新极快，将使用 alpha 版本替代 latest; 3. 默认优选改为 [ cn.azhz.eu.org ]
>
>2023.10.29 v1.0 正式版 1. Sing-box Family bucket v1.0; 2. After installing, add [sb] shortcut; 3. Output the configuration for Sing-box Client; 1. Sing-box 全家桶 v1.0; 2. 安装后，增加 [sb] 的快捷运行方式; 3. 输出 Sing-box Client 配置
>
>2023.10.18 beta7 1. You can add and remove protocols at any time, need to reinstall script; 2. Adjusted the order of some protocols; 1. 可以随时添加和删除协议，需要重新安装脚本; 2. 调整了部分协议的先后顺序
>
>2023.10.16 beta6 1. Support Alpine; 2. Add Sing-box PID, runtime, and memory usage to the menu; 3. Remove the option of using warp on returning to China; 支持 Alpine; 2. 菜单中增加 sing-box 内存占用显示; 3. 去掉使用 warp 回国的选项
>
>2023.10.10 beta5 1. Add the option of blocking on returning to China; 2. Add a number of quality cdn's that are collected online; 1. 增加禁止归国选项; 2. 增加线上收录的若干优质 cdn
>
>2023.10.9 beta4 1. Add v2rayN client, ShadowTLS and Tuic based on sing-box kernel configuration file output; 2. Shadowsocks encryption from aes-256-gcm to aes-128-gcm; 3. Optimize the routing and dns of sing-box on the server side; 1. 补充 v2rayN 客户端中，ShadowTLS 和 Tuic 基于 sing-box 内核的配置文件输出; 2. Shadowsocks 加密从 aes-256-gcm 改为 aes-128-gcm; 3. 优化服务端 sing-box 的 路由和 dns
>
>2023.10.6 beta3 1. Add vmess + ws / vless + ws + tls protocols; 2. Hysteria2 add obfuscated verification of obfs; 1. 增加 vmess + ws / vless + ws + tls 协议; 2. Hysteria2 增加 obfs 混淆验证
>
>2023.10.3 beta2 1. Single-select, multi-select or select all the required protocols; 2. Support according to the order of selection, the definition of the corresponding protocol listen port number; 1. 可以单选、多选或全选需要的协议; 2. 支持根据选择的先后次序，定义相应协议监听端口号
>
>2023.9.30 beta1 Sing-box 全家桶一键脚本 for vps
</details>


## 2.项目特点:

* 一键部署多协议，可以单选、多选或全选 ShadowTLS v3 / XTLS Reality / Hysteria2 / Tuic V5 / ShadowSocks / Trojan / Vmess + ws / Vless + ws + tls / H2 Reality / gRPC Reality, 总有一款适合你
* 所有协议均不需要域名，可选 Cloudflare Argo Tunnel 内网穿透以支持传统方式为 websocket 的协议
* 节点信息输出到 V2rayN / Clash Meta / 小火箭 / Nekobox / Sing-box (SFI, SFA, SFM)，订阅自动适配客户端，一个订阅 url 走天下
* 自定义端口，适合有限开放端口的 nat 小鸡
* 内置 warp 链式代理解锁 chatGPT
* 智能判断操作系统: Ubuntu 、Debian 、CentOS 、Alpine 和 Arch Linux,请务必选择 LTS 系统
* 支持硬件结构类型: AMD 和 ARM，支持 IPv4 和 IPv6
* 无交互极速安排模式: 一个回车完成超 10 个协议的安装


## 3.Sing-box for VPS 运行脚本:

* 首次运行
```
bash <(wget -qO- https://raw.githubusercontent.com/fscarmen/sing-box/main/sing-box.sh)
```

* 再次运行
```
sb
```

  | Option 参数      | Remark 备注 |
  | --------------- | ------ |
  | -c              | Chinese 中文 |
  | -e              | English 英文 |
  | -u              | Uninstall 卸载 |
  | -n              | Export Nodes list 显示节点信息 |
  | -p <start port> | Change the nodes start port 更改节点的起始端口 |
  | -s              | Stop / Start the Sing-box service 停止/开启 Sing-box 服务 |
  | -a              | Stop / Start the Argo Tunnel service 停止/开启 Argo Tunnel 服务 | 
  | -v              | Sync Argo Xray to the newest 同步 Argo Xray 到最新版本 |
  | -b              | Upgrade kernel, turn on BBR, change Linux system 升级内核、安装BBR、DD脚本 |
  | -r              | Add and remove protocols 添加和删除协议 |


## 4.无交互极速安装:
### 方式1. KV 配置文件，内容参照本库里的 config
```
bash <(wget -qO- https://raw.githubusercontent.com/fscarmen/sing-box/main/sing-box.sh) -f config
```

### 方式2. KV 传参，举例
```
bash <(wget -qO- https://raw.githubusercontent.com/fscarmen/sing-box/main/sing-box.sh) \
  --LANGUAGE c \
  --CHOOSE_PROTOCOLS a \
  --START_PORT 8881 \
  --PORT_NGINX 60000 \
  --SERVER_IP 123.123.123.123 \
  --CDN www.who.int \
  --VMESS_HOST_DOMAIN vmess.test.com \
  --VLESS_HOST_DOMAIN vless.test.com \
  --UUID_CONFIRM 20f7fca4-86e5-4ddf-9eed-24142073d197 \
  --NODE_NAME_CONFIRM test
```

### 参数说明
| Key 大小写不敏感（Case Insensitive）| Value |
| --------------- | ----------- |
| --LANGUAGE | c=中文;  e=英文 |
| --CHOOSE_PROTOCOLS | 可多选，如 bcdfk<br> a=全部<br> b=XTLS + reality<br> c=hysteria2<br> d=tuic<br> e=ShadowTLS<br> f=shadowsocks<br> g=trojan<br> h=vmess + ws<br> i=vless + ws + tls<br> j=H2 + reality<br> k=gRPC + reality |
| --START_PORT | 100 - 65520 |
| --PORT_NGINX | n=不需要订阅，或者 100 - 65520 |
| --SERVER_IP | IPv4 或 IPv6 地址，不需要中括号 |
| --CDN | 优选 IP 或者域名，如 --CHOOSE_PROTOCOLS 是 [a,h,i] 时需要 |
| --VMESS_HOST_DOMAIN | vmess sni 域名，如 --CHOOSE_PROTOCOLS 是 [a,h] 时需要 |
| --VLESS_HOST_DOMAIN | vless sni 域名，如 --CHOOSE_PROTOCOLS 是 [a,i] 时需要 |
| --UUID_CONFIRM | 协议的 uuid 或者 password |
| --NODE_NAME_CONFIRM | 节点名 |


## 5.Token Argo Tunnel 方案设置任意端口回源以使用 cdn
详细教程: [群晖套件：Cloudflare Tunnel 内网穿透中文教程 支持DSM6、7](https://imnks.com/5984.html)

<img width="1510" alt="image" src="https://github.com/fscarmen/sba/assets/62703343/bb2d9c43-3585-4abd-a35b-9cfd7404c87c">

<img width="1638" alt="image" src="https://github.com/fscarmen/sing-box/assets/62703343/a4868388-d6ab-4dc7-929c-88bc775ca851">


## 6.Vmess / Vless 方案设置任意端口回源以使用 cdn
举例子 IPv6: vmess [2a01:4f8:272:3ae6:100b:ee7a:ad2f:1]:10006
<img width="1052" alt="image" src="https://github.com/fscarmen/sing-box/assets/62703343/bc2df37a-95c4-4ba0-9c84-5d9c745c3a7b">

1. 解析域名
<img width="1605" alt="image" src="https://github.com/fscarmen/sing-box/assets/62703343/8f38d555-6294-493e-b43d-ff0586c80d61">

2. 设置 Origin rule
<img width="1556" alt="image" src="https://github.com/fscarmen/sing-box/assets/62703343/164bf255-a6be-40bc-a724-56e13da7a1e6">


## 7.Docker 和 Docker compose 安装

### 说明:
* 支持三种 Argo 类型隧道: 临时 (不需要域名) / Json / Token
* 需要20个连续可用的端口，以 `START_PORT` 开始第一个


### Docker 部署

```
docker run -dit \
    --pull always \
    --name sing-box \
    -p 8800-8820:8800-8820/tcp \
    -p 8800-8820:8800-8820/udp \
    -e START_PORT=8800 \
    -e SERVER_IP=123.123.123.123 \
    -e XTLS_REALITY=true \
    -e HYSTERIA2=true \
    -e TUIC=true \
    -e SHADOWTLS=true \
    -e SHADOWSOCKS=true \
    -e TROJAN=true \
    -e VMESS_WS=true \
    -e VLESS_WS=true \
    -e H2_REALITY=true \
    -e GRPC_REALITY=true \
    -e UUID=68fe8d27-cbc8-4e72-90b7-70d3bb69dfd3 \
    -e CDN=www.csgo.com \
    -e NODE_NAME=sing-box \
    -e ARGO_DOMAIN=sb.argo.com \
    -e ARGO_AUTH='{"AccountTag":"9cc9e3e4d8f29d2a02e297f14f20513a","TunnelSecret":"6AYfKBOoNlPiTAuWg64ZwujsNuERpWLm6pPJ2qpN8PM=","TunnelID":"1ac55430-f4dc-47d5-a850-bdce824c4101"}' \
    fscarmen/sb
```


### Docker Compose 部署
```
version: '3.8'
networks:
    sing-box:
        name: sing-box
services:
    sing-box:
        image: fscarmen/sb
        pull_policy: always
        container_name: sing-box
        restart: always
        networks:
            - sing-box
        ports:
            - "8800-8820:8800-8820/tcp"
            - "8800-8820:8800-8820/udp"
        environment:
            - START_PORT=8800
            - SERVER_IP=123.123.123.123
            - XTLS_REALITY=true
            - HYSTERIA2=true
            - TUIC=true
            - SHADOWTLS=true
            - SHADOWSOCKS=true
            - TROJAN=true
            - VMESS_WS=true
            - VLESS_WS=true
            - H2_REALITY=true
            - GRPC_REALITY=true
            - UUID=68fe8d27-cbc8-4e72-90b7-70d3bb69dfd3 
            - CDN=www.csgo.com
            - NODE_NAME=sing-box
            - ARGO_DOMAIN=sb.argo.com
            - ARGO_AUTH=eyJhIjoiOWNjOWUzZTRkOGYyOWQyYTAyZTI5N2YxNGYyMDUxM2EiLCJ0IjoiOGNiZDA4ZjItNGM0MC00OGY1LTlmZDYtZjlmMWQ0YTcxMjUyIiwicyI6IllXWTFORGN4TW1ZdE5HTXdZUzAwT0RaakxUbGxNMkl0Wm1VMk5URTFOR0l4TkdKayJ9
```


### 常用指令
| 功能 | 指令 |
| ---- | ---- |
| 查看节点信息 | `docker exec -it sing-box cat list` |
| 查看容器日志 | `docker logs -f sing-box` |
| 更新 Sing-box 版本 | `docker exec -it sing-box bash init.sh -v` |
| 查看容器内存,CPU，网络等资源使用情况 | `docker stats sing-box` |
| 暂停容器 | docker: `docker stop sing-box`</br> compose: `docker-compose stop` |
| 停止并删除容器 | docker: `docker rm -f sing-box`</br> compose: `docker-compose down` |
| 删除镜像 | `docker rmi -f fscarmen/sb:latest` |


### 用户可以通过 Cloudflare Json 生成网轻松获取: https://fscarmen.cloudflare.now.cc

<img width="784" alt="image" src="https://github.com/fscarmen/sba/assets/62703343/fb7c6e90-fb3e-4e77-bcd4-407e4660a33c">

如想手动，可以参考，以 Debian 为例，需要用到的命令，[Deron Cheng - CloudFlare Argo Tunnel 试用](https://zhengweidong.com/try-cloudflare-argo-tunnel)


### Argo Token 的获取

详细教程: [群晖套件：Cloudflare Tunnel 内网穿透中文教程 支持DSM6、7](https://imnks.com/5984.html)

<img width="1510" alt="image" src="https://github.com/fscarmen/sba/assets/62703343/bb2d9c43-3585-4abd-a35b-9cfd7404c87c">

<img width="1616" alt="image" src="https://github.com/fscarmen/sing-box/assets/62703343/ecb844be-1e93-4208-bb7c-6b00b9d1f00a">


### 参数说明
| 参数 | 是否必须 | 说明 |
| --- | ------- | --- |
| -p /tcp | 是 | 宿主机端口范围:容器 sing-box 及 nginx 等 tcp 监听端口 |
| -p /udp | 是 | 宿主机端口范围:容器 sing-box 及 nginx 等 udp 监听端口 |
| -e START_PORT | 是 | 起始端口 ，一定要与端口映射的起始端口一致 |
| -e SERVER_IP | 是 | 服务器公网 IP |
| -e XTLS_REALITY | 是 |    true 为启用 XTLS + reality，不需要的话删除本参数或填 false |
| -e HYSTERIA2 | 是 |       true 为启用 Hysteria v2 协议，不需要的话删除本参数或填 false |
| -e TUIC | 是 |            true 为启用 TUIC 协议，不需要的话删除本参数或填 false |
| -e SHADOWTLS | 是 |       true 为启用 ShadowTLS 协议，不需要的话删除本参数或填 false |
| -e SHADOWSOCKS | 是 |     true 为启用 ShadowSocks 协议，不需要的话删除本参数或填 false |
| -e TROJAN | 是 |          true 为启用 Trojan 协议，不需要的话删除本参数或填 false |
| -e VMESS_WS | 是 |        true 为启用 VMess over WebSocket 协议，不需要的话删除本参数或填 false |
| -e VLESS_WS | 是 |        true 为启用 VLess over WebSocket 协议，不需要的话删除本参数或填 false |
| -e H2_REALITY | 是 |      true 为启用 H2 over reality 协议，不需要的话删除本参数或填 false |
| -e GRPC_REALITY | 是 |    true 为启用 gRPC over reality 协议，不需要的话删除本参数或填 false |
| -e UUID | 否 | 不指定的话 UUID 将默认随机生成 |
| -e CDN | 否 | 优选域名，不指定的话将使用 www.csgo.com |
| -e NODE_NAME | 否 | 节点名称，不指定的话将使用 sing-box |
| -e ARGO_DOMAIN | 否 | Argo 固定隧道域名 , 与 ARGO_DOMAIN 一并使用才能生效 |
| -e ARGO_AUTH | 否 | Argo 认证信息，可以是 Json 也可以是 Token，与 ARGO_DOMAIN 一并使用才能生效，不指定的话将使用临时隧道 |


## 8.Nekobox 设置 shadowTLS 方法
1. 复制脚本输出的两个 Neko links 进去
<img width="630" alt="image" src="https://github.com/fscarmen/sing-box/assets/62703343/db5960f3-63b1-4145-90a5-b01066dd39be">

2. 设置链式代理，并启用
右键 -> 手动输入配置 -> 类型选择为 "链式代理"。

点击 "选择配置" 后，给节点起个名字，先后选 1-tls-not-use 和 2-ss-not-use，按 enter 或 双击 使用这个服务器。一定要注意顺序不能反了，逻辑为 ShadowTLS -> ShadowSocks。

<img width="408" alt="image" src="https://github.com/fscarmen/sing-box/assets/62703343/753e7159-92f9-4c88-91b5-867fdc8cca47">


## 9.主体目录文件及说明

```
/etc/sing-box/                               # 项目主体目录
|-- cert                                     # 存放证书文件目录
|   |-- cert.pem                             # SSL/TLS 安全证书文件
|   `-- private.key                          # SSL/TLS 证书的私钥信息
|-- conf                                     # sing-box server 配置文件目录
|   |-- 00_log.json                          # 日志配置文件
|   |-- 01_outbounds.json                    # 服务端出站配置文件，已加了 warp 账户信息
|   |-- 02_route.json                        # 路由配置文件，chatGPT 使用 warp ipv6 链式代理出站
|   |-- 03_experimental.json                 # 缓存配置文件
|   |-- 04_dns.json                          # DNS 规则文件
|   |-- 11_xtls-reality_inbounds.json        # Reality vision 协议配置文件
|   |-- 12_hysteria2_inbounds.json           # Hysteria2 协议配置文件
|   |-- 13_tuic_inbounds.json                # Tuic V5 协议配置文件 # Hysteria2 协议配置文件
|   |-- 14_ShadowTLS_inbounds.json           # ShadowTLS 协议配置文件     # Tuic V5 协议配置文件
|   |-- 15_shadowsocks_inbounds.json         # Shadowsocks 协议配置文件
|   |-- 16_trojan_inbounds.json              # Trojan 协议配置文件
|   |-- 17_vmess-ws_inbounds.json            # vmess + ws 协议配置文件
|   |-- 18_vless-ws-tls_inbounds.json        # vless + ws + tls 协议配置文件
|   |-- 19_h2-reality_inbounds.json          # Reality http2 协议配置文件
|   `-- 20_grpc-reality_inbounds.json        # Reality gRPC 协议配置文件
|-- logs
|   `-- box.log                              # sing-box 运行日志文件
|-- subscribe                                # sing-box server 配置文件目录
|   |-- qr                                   # Nekoray / V2rayN / Shadowrock 订阅二维码
|   |-- shadowrocket                         # Shadowrock 订阅文件
|   |-- proxies                              # Clash proxy provider 订阅文件
|   |-- clash                                # Clash 订阅文件1
|   |-- clash2                               # Clash 订阅文件2
|   |-- sing-box-pc                          # SFM 订阅文件1
|   |-- sing-box-phone                       # SFI / SFA 订阅文件1
|   |-- sing-box2                            # SFI / SFA / SFM 订阅文件2
|   |-- v2rayn                               # V2rayN 订阅文件
|   `-- neko                                 # Nekoray 订阅文件
|-- cache.db                                 # sing-box 缓存文件
|-- nginx.conf                               # 用于订阅服务的 nginx 配置文件
|-- language                                 # 存放脚本语言文件，E 为英文，C 为中文
|-- list                                     # 节点信息列表
|-- sing-box                                 # sing-box 主程序
|-- cloudflared                              # Argo tunnel 主程序
|-- tunnel.json                              # Argo tunnel Json 信息文件
|-- tunnel.yml                               # Argo tunnel 配置文件
|-- sb.sh                                    # 快捷方式脚本文件
|-- jq                                       # 命令行 json 处理器二进制文件
`-- qrencode                                 # QR 码编码二进制文件
```


## 10.鸣谢下列作者的文章和项目:
千歌 sing-box 模板: https://github.com/chika0801/sing-box-examples  
瞎折腾 sing-box 模板: https://t.me/ztvps/100


## 11.免责声明:
* 本程序仅供学习了解, 非盈利目的，请于下载后 24 小时内删除, 不得用作任何商业用途, 文字、数据及图片均有所属版权, 如转载须注明来源。
* 使用本程序必循遵守部署免责声明。使用本程序必循遵守部署服务器所在地、所在国家和用户所在国家的法律法规, 程序作者不对使用者任何不当行为负责。