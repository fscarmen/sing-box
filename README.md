# 【Sing-box 全家桶】

* * *

# 目录

- [更新信息](README.md#更新信息)
- [项目特点](README.md#项目特点)
- [Sing-box for VPS 运行脚本](README.md#sing-box-for-vps-运行脚本)
- [Sekobox 设置 shadowTLS 方法](README.md#sekobox-设置-shadowtls-方法)
- [免责声明](README.md#免责声明)

* * *
## 更新信息

2023.9.30 beta1 Sing-box 全家桶一键脚本 for vps


## 项目特点:

* 一键部署多协议，包含但不仅限于 ShadowTLS v3 / Reality / Hysteria2 / Tuic V5 / ShadowSocks / Trojan, 总有一款适合你
* 内置 warp 链式代理解锁 chatGPT
* 不需要域名
* 智能判断操作系统: Ubuntu 、Debian 、CentOS 、Alpine 和 Arch Linux,请务必选择 LTS 系统
* 支持硬件结构类型: AMD 和 ARM，支持 IPv4 和 IPv6

## Sing-box for VPS 运行脚本:

```
bash <(wget -qO- https://raw.githubusercontent.com/fscarmen/sing-box/main/sing-box.sh)
```

  | Option 参数 | Remark 备注 | 
  | -----------| ------ |
  | -c         | Chinese 中文 |
  | -e         | English 英文 | 
  | -u         | Uninstall 卸载 |
  | -n         | Export Nodes list 显示节点信息 |
  | -v         | Sync Argo Xray to the newest 同步 Argo Xray 到最新版本 |
  | -b         | Upgrade kernel, turn on BBR, change Linux system 升级内核、安装BBR、DD脚本 |


## Sekobox 设置 shadowTLS 方法
1. 复制脚本输出的两个 Neko links 进去
<img width="630" alt="image" src="https://github.com/fscarmen/sing-box/assets/62703343/db5960f3-63b1-4145-90a5-b01066dd39be">

2. 设置链式代理，并启用
右键 -> 手动输入配置 -> 类型选择为 "链式代理"。

点击 "选择配置" 后，给节点起个名字，先后选 1-tls-not-use 和 2-ss-not-use，按 enter 或 双击 使用这个服务器。一定要注意顺序不能反了，逻辑为 ShadowTLS -> ShadowSocks。

<img width="408" alt="image" src="https://github.com/fscarmen/sing-box/assets/62703343/753e7159-92f9-4c88-91b5-867fdc8cca47">


## 免责声明:
* 本程序仅供学习了解, 非盈利目的，请于下载后 24 小时内删除, 不得用作任何商业用途, 文字、数据及图片均有所属版权, 如转载须注明来源。
* 使用本程序必循遵守部署免责声明。使用本程序必循遵守部署服务器所在地、所在国家和用户所在国家的法律法规, 程序作者不对使用者任何不当行为负责。
