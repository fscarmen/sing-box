# Xray 可选监控（面板 2.5.3）

本项目已支持部署和管理 Xray，使用方法见 [Xray 部署与网页管理](XRAY-DEPLOY.md)。本文用于接入已有外部 Xray 实例：外部实例只接入监控，不开放配置写入、升级或订阅生成；“服务器管理 → Xray”仅操作本项目创建的实例。

## 接入已有实例

先确认 Xray 本身运行正常。在其有效配置中开启 StatsService 和入站/出站/用户统计，统计 API 只监听回环。可参考 `dashboard/deploy/xray-stats.example.json`；合并配置前应备份并用 `xray run -test` 检查，重启 Xray 会短暂中断代理连接。

给需要用户统计的客户端配置唯一 `email`，并开启相应用户 level 的 `statsUserUplink`、`statsUserDownlink`、`statsUserOnline`。用户统计依赖核心版本；本项目原生测试使用官方 Xray v26.10.21，旧版本不提供的能力显示未知。

在 `/etc/sb-dashboard/settings.json` 根对象增加以下段落，保留原有其他设置：

```json
{
  "xray": {
    "instances": [
      {
        "id": "main",
        "label": "Xray 主实例",
        "service": "xray.service",
        "api_address": "127.0.0.1:8311",
        "config_path": "/etc/xray/config.json"
      }
    ],
    "poll_seconds": 2,
    "access_control": false
  }
}
```

请按实际配置修改实例路径、服务名和 API 地址；面板账户 `sb-dashboard` 需要读取 Xray 配置。仅向该组授予必要文件的读取/目录遍历权限，不要把含凭据的配置公开可读。API 没有公网认证保护，不可暴露到公网。

执行 `sudo systemctl restart sb-dashboard`。配置有 Xray 后，面板默认显示 Xray；侧栏可切换回 sing-box，“服务器管理”和原固定订阅仍可使用。重复运行本项目安装器会保留 Xray、探测和大陆检测的文件配置。

统计保存在 `/var/lib/sb-dashboard/xray-traffic.sqlite3`，不会混入 sing-box 账本。它按接入后的采样增量计量，不回填部署之前的历史；按用户 email 的流量不会分摊到某个来源 IP。Xray 不提供逐连接字节、目标域名历史或关闭单连接接口。

## 封禁与探测

sing-box 的公开入站按 TCP/UDP 分别建立防火墙规则，覆盖 Hysteria2、TUIC 等 UDP 入站。Xray 端口封禁默认关闭，需要时设置 `xray.access_control=true` 并重启面板。只作用于识别出的公网节点端口；经过 CDN/回环的入口仍需独立配置回源封禁网关。

默认出口探测包含 Cloudflare trace 和 Instagram、YouTube、Facebook 的 HTTPS 检查。只有有效 trace 回显用于确认出口 IP；媒体检查成功不等于视频播放、账号登录或完整代理握手成功。可以通过 `probes.targets` 自定义目标。

公开大陆入口检查默认关闭，配置项为 `reachability`：

```json
{
  "reachability": {
    "enabled": false,
    "interval_seconds": 600,
    "failures": 2,
    "targets": [{"id": "panel", "label": "公开登录页", "host": "panel.example.com", "path": "/monitor/login"}]
  }
}
```

开启后，会把上述无令牌的公开主机名/页面提交给 Globalping 的公开检测平台，分别观察电信、联通、移动。允许的路径仅为 `/`、`/monitor/login`、`/favicon.ico`；不要配置订阅密钥或私人入口。结果不代表完整订阅下载或节点连接成功，平台缺少节点或检测异常时显示未知，不视为恢复。
