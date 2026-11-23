# 固定订阅域名

没有域名也能部署：先在面板下载完整配置导入客户端。需要自动更新且不想更换订阅链接时，再完成以下设置。

## 1. 准备域名

在任意注册商购买域名。在 [Cloudflare](https://dash.cloudflare.com/) 添加这个域名，选择 Free，按页面指引把注册商的 Nameservers 改成 Cloudflare 分配的两条地址。等待域名状态为 Active。

域名留在原注册商续费，不需要转移注册商。自有域名和命名隧道可以保持地址固定；`trycloudflare.com` Quick Tunnel 不是固定入口。

## 2. 建立固定隧道

按 [Cloudflare 官方步骤](https://developers.cloudflare.com/tunnel/get-started/) 创建一个命名隧道。在同一台 VPS 上执行 Cloudflare 页面提供的 Linux 安装和服务启动命令，等待隧道 Healthy。安装命令含私有令牌，只在自己的 VPS 终端执行，不要上传到 GitHub。

添加 Published application 路由：

| 项目 | 填写内容 |
| --- | --- |
| Hostname | `sub.你购买的域名` |
| Service 类型 | HTTP |
| Service URL | `127.0.0.1:8308` |

如果界面只有一个 URL 输入框，填写 `http://127.0.0.1:8308`。

8308 是项目自带的只读订阅网关，仅监听本机回环，不需要在云安全组开放。它不提供面板、登录或管理 API。HTTPS 由 Cloudflare 提供，访问者不需要信任面板的自签名证书。

本步骤不需要给服务器 IP 添加 A 记录，也不需要把面板端口作为隧道回源。

## 3. 在面板保存域名

进入“服务器管理 → 客户端配置与订阅 → 设置固定订阅域名”，填写：

```text
https://sub.你的域名
```

保存并等待任务成功。复制新的“自动识别”链接，在 Clash Meta 或 Shadowrocket 添加订阅；两个客户端可以使用同一条 `/auto` 链接。也可以选对应客户端的固定格式链接。

更改下载域名不会改节点的 IP、端口、Host/SNI 或凭据。以后重新生成订阅、修改节点、更新面板、重启 VPS，下载路径中的订阅密钥会保留。迁往其他 VPS 时，需要同时保留 `/var/lib/sb-manager/subscription.json`，并在新服务器运行同一个隧道，才能沿用完整链接。

域名按时续费，并保持 VPS 和隧道在线。固定地址不代表永远没有网络故障。

## 验证与排查

从面板复制完整链接，用手机关闭代理后更新一次。

- 404：先确认安装任务成功，已经生成客户端文件；链接必须带完整密钥和格式路径。直接访问域名首页返回 404 是正常行为。
- Cloudflare 1033：隧道没有在线，检查 Cloudflare 提供的服务及连接状态。
- Cloudflare 502：确认 `systemctl status sb-subscription` 正常，回源为 HTTP `127.0.0.1:8308`。
- 浏览器能打开但客户端更新失败：订阅路径不应要求 Cloudflare Access 网页登录或交互验证码。
- 默认 IP 链接证书错误：使用固定域名，或先下载完整配置导入；不要给手机全局关闭证书校验。

不要把完整订阅链接、Cloudflare 令牌或 `/etc/sb-dashboard/` 内容上传到公开仓库。
