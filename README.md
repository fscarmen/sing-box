# 【Sing-box 全家桶】

* * *

# 目录

- [更新信息](README.md#更新信息)
- [项目特点](README.md#项目特点)
- [Sing-box for VPS 运行脚本](README.md#sing-box-for-vps-运行脚本)
- [Vmess / Vless 方案设置任意端口回源以使用 cdn](README.md#Vmess--Vless-方案设置任意端口回源以使用-cdn)
- [Nekobox 设置 shadowTLS 方法](README.md#nekobox-设置-shadowtls-方法)
- [鸣谢下列作者的文章和项目](README.md#鸣谢下列作者的文章和项目)
- [免责声明](README.md#免责声明)

* * *
## 更新信息
2023.10.6 beta3 1. Add vmess + ws / vless + ws + tls protocols; 2. Hysteria2 add obfuscated verification of obfs; 1. 增加 vmess + ws / vless + ws + tls 协议; 2. Hysteria2 增加 obfs 混淆验证

2023.10.3 beta2 1. Single-select, multi-select or select all the required protocols; 2. Support according to the order of selection, the definition of the corresponding protocol listen port number; 1. 可以单选、多选或全选需要的协议; 2. 支持根据选择的先后次序，定义相应协议监听端口号

2023.9.30 beta1 Sing-box 全家桶一键脚本 for vps


## 项目特点:

* 一键部署多协议，可以单选、多选或全选 ShadowTLS v3 / Reality / Hysteria2 / Tuic V5 / ShadowSocks / Trojan / Vmess + ws / Vless + ws + tls, 总有一款适合你
* 自定义端口，适合有限开放端口的 nat 小鸡
* 内置 warp 链式代理解锁 chatGPT
* 不需要域名 ( vmess / vless 方案例外)
* 智能判断操作系统: Ubuntu 、Debian 、CentOS 、Alpine 和 Arch Linux,请务必选择 LTS 系统
* 支持硬件结构类型: AMD 和 ARM，支持 IPv4 和 IPv6

## Sing-box for VPS 运行脚本:

```
bash <(wget -qO- https://raw.githubusercontent.com/fscarmen/sing-box/main/sing-box.sh)
```

  | Option 参数      | Remark 备注 | 
  | --------------- | ------ |
  | -c              | Chinese 中文 |
  | -e              | English 英文 | 
  | -u              | Uninstall 卸载 |
  | -n              | Export Nodes list 显示节点信息 |
  | -p <start port> | Change the nodes start port 更改节点的起始端口 |
  | -o              | Stop / Start the Sing-box service 停止/开启 Sing-box 服务 |
  | -v              | Sync Argo Xray to the newest 同步 Argo Xray 到最新版本 |
  | -b              | Upgrade kernel, turn on BBR, change Linux system 升级内核、安装BBR、DD脚本 |


## Vmess / Vless 方案设置任意端口回源以使用 cdn
举例子 IPv6: vmess [2a01:4f8:272:3ae6:100b:ee7a:ad2f:1]:10006
<img width="1052" alt="image" src="https://github.com/fscarmen/sing-box/assets/62703343/bc2df37a-95c4-4ba0-9c84-5d9c745c3a7b">

1. 解析域名
<img width="1605" alt="image" src="https://github.com/fscarmen/sing-box/assets/62703343/8f38d555-6294-493e-b43d-ff0586c80d61">

2. 设置 Origin rule
<img width="1556" alt="image" src="https://github.com/fscarmen/sing-box/assets/62703343/164bf255-a6be-40bc-a724-56e13da7a1e6">


## Nekobox 设置 shadowTLS 方法
1. 复制脚本输出的两个 Neko links 进去
<img width="630" alt="image" src="https://github.com/fscarmen/sing-box/assets/62703343/db5960f3-63b1-4145-90a5-b01066dd39be">

2. 设置链式代理，并启用
右键 -> 手动输入配置 -> 类型选择为 "链式代理"。

点击 "选择配置" 后，给节点起个名字，先后选 1-tls-not-use 和 2-ss-not-use，按 enter 或 双击 使用这个服务器。一定要注意顺序不能反了，逻辑为 ShadowTLS -> ShadowSocks。

<img width="408" alt="image" src="https://github.com/fscarmen/sing-box/assets/62703343/753e7159-92f9-4c88-91b5-867fdc8cca47">


## 鸣谢下列作者的文章和项目:
千歌 sing-box 模板: https://github.com/chika0801/sing-box-examples


## 免责声明:
* 本程序仅供学习了解, 非盈利目的，请于下载后 24 小时内删除, 不得用作任何商业用途, 文字、数据及图片均有所属版权, 如转载须注明来源。
* 使用本程序必循遵守部署免责声明。使用本程序必循遵守部署服务器所在地、所在国家和用户所在国家的法律法规, 程序作者不对使用者任何不当行为负责。