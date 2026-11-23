# 安装与维护

## 支持范围

- 全新 Debian 12+ / Ubuntu 22.04+ VPS，以 systemd 启动。
- root 或 sudo 权限，amd64 / arm64，至少 1 GiB 空闲磁盘；建议至少 1 GiB 内存。
- 能访问 GitHub、Debian/Ubuntu 软件源和 Python 包源。
- 默认安装 sing-box **1.14.3**，Reality TCP 443 与 Hysteria2 UDP 444。首次安装和网页升级都校验官方 GitHub release 的 SHA256。

不需要先安装 sing-box、Python、Node、Nginx，也不需要先准备域名。面板前端已经构建在仓库内，服务器无需 Node。Docker 仅用于开发测试，正常安装不依赖 Docker。

## 标准安装

通过服务商网页终端或 SSH 登录 VPS，执行：

```bash
sudo apt-get update && sudo apt-get install -y curl ca-certificates
curl -fL --retry 2 https://raw.githubusercontent.com/fscarmen/sing-box/main/bootstrap.sh -o bootstrap.sh
sudo bash bootstrap.sh
```

引导器识别公网地址，安装独立 HTTPS 面板及默认节点。安装可能需要几分钟，结束时会显示面板地址。

```bash
sudo cat /root/sb-dashboard-login.txt
```

这条命令查看 `admin` 账号的随机密码。密码不会打印进安装日志。

在浏览器打开安装结果中的 `https://服务器IP:8443/monitor/`。首次使用自签名证书，浏览器会提示证书未受信任；核对服务器 IP 后处理提示。用自己的受信任证书可消除提示，方法见下文。

服务商有云防火墙/安全组时，放行 TCP **8443**、TCP **443**、UDP **444**；SSH 端口保持原设置。脚本处理本机节点及面板端口规则，但不能替你修改云平台安全组。

## 自定义安装

```bash
# 指定面板访问地址与端口（NAT VPS 应填写真正能访问的公网地址）
sudo bash bootstrap.sh --port 18443 --public-url https://你的公网IP:18443

# 改为 Xray Reality + Vision（默认 TCP 443）
sudo bash bootstrap.sh --engine xray

# 先只部署面板，再在网页安装向导选择内核与节点端口
sudo bash bootstrap.sh --panel-only

# 使用已有受信任证书：私钥与证书链必须匹配
sudo bash bootstrap.sh --public-url https://panel.example.com:8443 \
  --tls-cert /已有证书/fullchain.pem --tls-key /已有证书/privkey.pem

# 只读检查，不安装、不改配置
sudo bash bootstrap.sh --check-only

# 上传完整仓库后，本地安装；不需要代码已经发布
sudo bash bootstrap.sh --source-dir /上传的完整仓库
```

参数 `--ref` 指定下载的分支、标签或提交。未使用 `--source-dir` 且安装器旁边没有完整源码时，会从本 fork 下载对应版本。

证书会复制到 `/etc/sb-dashboard/tls.crt` 和 `tls.key`，权限为 root:sb-dashboard 0640。项目不会自动申请或续期证书；续期后复制新文件并重启 `sb-dashboard`。提供证书的主机名应与 `--public-url` 一致。

## 导入客户端

面板“服务器管理 → 客户端配置与订阅”提供：

- 自动识别订阅链接，支持 Clash Meta、Shadowrocket、sing-box 等客户端。
- 完整配置复制/下载。没有受信任 HTTPS 域名时，优先下载 `clash2` 完整配置导入 Clash；Shadowrocket 选择对应格式。
- 可选固定域名。见 [固定订阅域名](docs/FIXED-SUBSCRIPTION.md)，接入后在面板保存地址，后续导出保留密钥和域名。

默认 IP 订阅使用面板的自签名证书，客户端可能拒绝更新；它不能代替受信任证书或固定域名。默认节点部署不开放额外 HTTP 订阅端口，也不创建临时 Quick Tunnel。

## 日常管理

“服务器管理”支持节点服务启停、配置编辑、端口与 SNI/带宽表单、订阅更新、指定版本升级、配置备份恢复和后台任务记录。管理任务独立于浏览器，关闭网页不会取消任务。

配置编辑器操作 `/etc/sing-box/conf/*.json`。保留顶部 `//` 元数据；订阅导出依赖这些信息。`09_dashboard_api.json` 由管理服务维护。提交前备份并检查候选配置；应用后失败会尝试恢复。仅校验通过不保证公网可达，需要实际客户端连接验证。

协议增删可通过对应入站文件操作；复杂 WS/CDN/Argo、端口跳跃、内核/BBR/DD 和卸载使用 [原脚本高级说明](README.md)。WS/CDN 域名和回源需事先配置。不要同时在 shell 菜单和网页修改配置。

Xray 的配置路径、支持协议、双核心共存与独立订阅见 [Xray 部署与管理](docs/XRAY-DEPLOY.md)。网页“管理内核”选择器用于切换操作目标，监控侧栏的来源选择器用于切换统计。

## 客户端规则

“代理规则”统一设置目标的代理、直连和拒绝策略，支持从 sing-box 连接历史直接添加。Clash/sing-box 更新完整配置后生效；Shadowrocket 需另外导入并更新远程规则配置，节点订阅本身不携带规则。面板展示的是服务器当前下发规则，无法读取设备本地覆写。详见 [客户端规则说明](docs/CLIENT-RULES.md)。

## 忘记密码

SSH 登录 VPS 后执行：

```bash
sudo sb-dashboard-admin reset-password
sudo cat /root/sb-dashboard-login.txt
```

恢复工具生成新密码并撤销旧登录会话，仅重启面板，保留节点、订阅密钥和流量历史。

## 更新面板与重复运行

等待网页任务结束，再下载新版安装器并运行。引导器保留管理员密码、账本、订阅密钥和已经保存的固定域名；已有受管理节点不会因为重复引导再次重启。未安装所选默认内核时继续安装；重复运行保留首次选择的默认内核，需要仅更新面板时使用 `--panel-only`。

更新前的私有面板配置会保存在 `/var/lib/sb-manager/bootstrap-backups/`，旧代码发布保留于 `/opt/sb-dashboard/releases/`。更新并不等于整机事务回滚；系统依赖、证书续期、云安全组需要自行维护。其他部署器的配置拒绝自动接管，不包含旧监控账本迁移功能。

## 目录与服务

| 路径/服务 | 用途 |
| --- | --- |
| `/opt/sb-dashboard/current` | 当前面板和部署脚本版本 |
| `/etc/sb-dashboard/` | 账户哈希、设置、API 密钥和证书 |
| `/var/lib/sb-dashboard/stats.sqlite3` | 流量历史、会话与审计 |
| `/var/lib/sb-manager/` | 私有任务、配置备份、订阅密钥与固定地址 |
| `/var/lib/sb-subscriptions/` | 面板与订阅网关只读的客户端导出 |
| `sb-dashboard` | 独立非 root HTTPS 面板，默认 8443 |
| `sb-manager` | root 管理服务，仅 Unix socket |
| `sb-subscription` | 非 root 订阅网关，仅 `127.0.0.1:8308` |
| `sing-box` | sing-box 节点核心，监控 API 仅 `127.0.0.1:8306` |
| `xray` | 可选 Xray 节点核心，StatsService 仅 `127.0.0.1:8311` |

主管理员可以修改服务器和读取节点凭据，额外监控账户没有管理权限。8306、8308、8311 和管理 socket 不应对公网开放。直接访问面板时不信任客户端来源 IP 头。

查看服务状态：

```bash
sudo systemctl status sb-dashboard sb-manager sb-subscription sing-box --no-pager
sudo journalctl -u sb-dashboard -u sb-manager -u sb-subscription -n 80 --no-pager
```

出现安装任务失败时，先查看网页任务记录。依赖下载失败可检查 VPS 到 GitHub/软件源的连接后重试；首次节点安装失败可能留下部分系统依赖和配置，面板仍可用于检查。端口被占用时，使用安装向导指定空闲端口。

监控属地数据库未附带，未安装时属地显示未知，不影响部署及主要监控功能。IPv6-only、arm64 的完整部署和真实 systemd 重启行为仍需实际对应 VPS 验证，见 [验证记录](BOOTSTRAP-VALIDATION.md)。
