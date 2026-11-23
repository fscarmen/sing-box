# Xray 部署与网页管理

本项目集成官方 [XTLS/Xray-install](https://github.com/XTLS/Xray-install) 安装脚本，固定于 `b0d349e9c6234e8fa1b0d50ca9a29ce54452918f`，脚本原样保存于 `dashboard/vendor/xray-install/`，同时保留 GPL-3.0 许可证和 SHA256 来源记录。管理服务校验官方 Xray release 的 ZIP SHA256，再调用本地脚本安装；不执行浮动远程 shell。

首次安装固定 Xray **26.10.21**，支持 Linux amd64/arm64、Debian 12+/Ubuntu 22.04+、systemd。当前支持部署和导出 **VLESS + Reality + Vision（RAW/TCP）**，无需自己的域名或节点证书。面板 HTTPS 证书与节点 Reality 是两回事，订阅使用受信任 HTTPS 域名的方法见 [固定订阅](FIXED-SUBSCRIPTION.md)。

## 全新 VPS

按主 README 下载 `bootstrap.sh` 后，运行：

```bash
sudo bash bootstrap.sh --engine xray
```

云安全组放行面板 TCP 8443 和节点 TCP 443，SSH 端口保持原样。登录面板后进入“服务器管理”，将“管理内核”设为 **Xray**；下载配置或复制自动识别订阅链接导入 Clash Meta / Shadowrocket。

也可先只安装面板：

```bash
sudo bash bootstrap.sh --panel-only
```

在网页选择 Xray，填写服务器公网 IP/域名、节点名、空闲端口和 Reality SNI，点击“开始安装”。后台任务完成后，刷新页面即可看到 Xray 原生统计。

默认 Reality SNI 为 `www.apple.com`，可通过网页或 `--reality-sni` 修改。目标需要支持 TLS 1.3，建议支持 h2，并能从 VPS 访问；公网链路和客户端是否可用仍需实际连接验证，不应把配置校验成功等同于连通成功。

## 与 sing-box 共存

两个内核使用独立服务、配置、备份和订阅密钥，不会替换原来的 sing-box 节点。若已有 sing-box 占用 TCP 443，请在网页选空闲端口，例如 9443；或执行：

```bash
sudo bash bootstrap.sh --engine xray --node-port 9443
```

放行所选端口对应的云安全组。面板/内部 API/订阅端口不能用作节点端口，安装或改端口时也会检查实际占用。已有外部 Xray 文件或服务会拒绝覆盖，外部实例按 [可选监控说明](XRAY-MONITOR.md) 接入。

## 后续网页操作

- 端口和 SNI：加载配置，用表单更新草稿，再“校验并应用”。SNI 表单会同步 `serverNames` 与 `target`。
- 公网地址：修改“客户端连接的服务器 IP / 域名”，应用后重新导出客户端配置。
- 用户：在 `config.json` 的 `settings.clients` 增加唯一 UUID 和唯一 `email`，保留 `flow: xtls-rprx-vision` 与 `level: 0`。每个用户都有独立统计和客户端条目。
- 节点：复制 Reality 入站，设置唯一 `tag`、端口和用户 email。当前自动导出支持 Reality RAW/TCP，其他协议不会静默导出错误订阅。
- 配置、出站和路由：可在 JSON 编辑器调整。StatsService、统计 policy 由项目维护，只监听 `127.0.0.1:8311`。
- 升级：填明确版本，如 `26.10.21`。先校验官方 SHA256 和当前配置，再替换、重启；检查失败尝试恢复原内核和配置。
- 恢复：从 Xray 自己的备份列表选择。配置、连接地址恢复，统计历史与订阅密钥保留。

两个内核共用一个串行任务锁，不能同时改配置。任务日志记录阶段与结果，不记录配置、UUID 或 Reality 私钥。管理入口需要主管理员登录与 CSRF；监控账户不会获得部署权限。

## 订阅和固定域名

同一个只读网关 `127.0.0.1:8308` 提供两种内核的订阅，但各自拥有独立下载密钥和链接。在 Xray 的“客户端配置与订阅”里保存已接入的固定 HTTPS 域名，后续导出、改端口、恢复和升级会保持其链接。

原来的 sing-box 订阅链接继续使用；它不会自动加入 Xray 节点。要使用 Xray，需要把 Xray 页显示的新订阅加入客户端。导出支持 Clash Meta 完整配置、Shadowrocket/v2rayN URI 订阅和 sing-box outbound JSON；旧版不支持 Reality 的客户端需要先更新。

## 文件和恢复排查

| 路径/服务 | 用途 |
| --- | --- |
| `/usr/local/bin/xray` | 官方 Xray 核心 |
| `/usr/local/etc/xray/config.json` | root:xray 0640 节点配置 |
| `xray.service` | 非 root xray 用户的节点服务，独立于面板 |
| `/var/lib/sb-manager/xray-managed.json` | 本项目所有权记录及连接地址 |
| `/var/lib/sb-manager/xray-backups/` | 私有配置备份 |
| `/var/lib/sb-manager/xray-subscription.json` | 私有固定订阅域名和稳定密钥 |
| `/var/lib/sb-subscriptions/xray/` | 原子发布的只读客户端配置 |
| `/var/lib/sb-dashboard/xray-runtime.json` | 面板可读的监控配置快照 |
| `/var/lib/sb-dashboard/xray-traffic.sqlite3` | 独立流量账本 |

```bash
sudo systemctl status xray sb-dashboard sb-manager
sudo journalctl -u xray -n 50 --no-pager
sudo /usr/local/bin/xray run -test -config /usr/local/etc/xray/config.json
```

节点停止不会停止面板。重复运行安装器保留首次选择的默认内核、账号、节点参数、订阅和流量数据；已有受管节点不会仅因重复引导而重启。升级面板可明确使用 `--panel-only`。

本机防火墙只增加受管节点的放行规则，不清空已有规则或改 SSH。iptables 的旧受管端口规则会按注释移除；UFW/firewalld 可能与人工放行共用端口，旧放行规则保留，需要时由管理员检查。配置本身已不再监听旧端口。脚本不会安装另一套管理面板，也不自动卸载或迁移已有 Xray。
