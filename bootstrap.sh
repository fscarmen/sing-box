#!/usr/bin/env bash
# Bootstrap the independent HTTPS panel, then Reality + Hysteria2 on this VPS.
set -Eeuo pipefail
umask 077

REPO=fscarmen/sing-box
REF=main
SOURCE_DIR=''
PUBLIC_URL=''
PORT=8443
PORT_EXPLICIT=0
TLS_CERT=''
TLS_KEY=''
PANEL_ONLY=0
CHECK_ONLY=0
ENGINE=singbox
ENGINE_EXPLICIT=0
NODE_PORT=443
REALITY_SNI=www.apple.com
PREFIX=/opt/sb-dashboard
CONFIG=/etc/sb-dashboard
DATA=/var/lib/sb-dashboard
usage() {
  cat <<'HELP'
用法：sudo bash bootstrap.sh [参数]
  --public-url URL  浏览器访问源，例如 https://203.0.113.10:8443（推荐显式指定）
  --port PORT       面板 HTTPS 端口，默认 8443
  --panel-only      只安装面板，随后在网页选择内核部署
  --engine CORE     首次部署内核：singbox（默认）或 xray
  --node-port PORT  Xray Reality TCP 端口，默认 443（与 sing-box 共存可用 9443）
  --reality-sni DNS Xray Reality 目标域名，默认 www.apple.com
  --source-dir DIR  使用完整本地仓库（适合上传未发布的代码）
  --ref REF         下载仓库的指定分支、标签或提交，默认 main
  --tls-cert FILE   已有受信任证书链文件（与 --tls-key 同时使用）
  --tls-key FILE    已有证书私钥文件，安装时复制到私有配置目录
  --check-only      只读检查系统、空间、端口与现有安装
  --help            显示帮助
支持 Debian 12+/Ubuntu 22.04+、systemd、amd64/arm64；默认 sing-box Reality TCP443 + Hysteria2 UDP444；Xray 为 Reality TCP443。
面板独立运行，不依赖 sing-box/Nginx/Argo；首次使用自签名 HTTPS 证书。
HELP
}
while (($#)); do
  case "$1" in
    --public-url|--port|--source-dir|--ref|--tls-cert|--tls-key|--engine|--node-port|--reality-sni)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      case "$1" in
        --public-url) PUBLIC_URL=$2;;
        --port) PORT=$2; PORT_EXPLICIT=1;;
        --source-dir) SOURCE_DIR=$2;;
        --ref) REF=$2;;
        --tls-cert) TLS_CERT=$2;;
        --tls-key) TLS_KEY=$2;;
        --engine) ENGINE=$2; ENGINE_EXPLICIT=1;;
        --node-port) NODE_PORT=$2;;
        --reality-sni) REALITY_SNI=$2;;
      esac
      shift 2;;
    --panel-only) PANEL_ONLY=1; shift;;
    --check-only) CHECK_ONLY=1; shift;;
    -h|--help) usage; exit 0;;
    *) printf '未知参数：%s\n' "$1" >&2; exit 2;;
  esac
done
if ((!ENGINE_EXPLICIT)) && [[ -r "$CONFIG/manager.json" ]] && command -v python3 >/dev/null; then
  ENGINE=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("default_engine","singbox"))' "$CONFIG/manager.json")
fi
[[ "$ENGINE" == singbox || "$ENGINE" == xray ]] || { echo '--engine 仅支持 singbox 或 xray'; exit 2; }
[[ "$NODE_PORT" =~ ^[0-9]+$ ]] && ((NODE_PORT >= 100 && NODE_PORT <= 65535)) || { echo 'Xray 节点端口需为 100–65535'; exit 2; }
if ((!PORT_EXPLICIT)) && [[ -r "$CONFIG/settings.json" ]] && command -v python3 >/dev/null; then
  PORT=$(python3 -c 'import json,sys;from urllib.parse import urlsplit;print(urlsplit(json.load(open(sys.argv[1]))["site"]["public_url"]).port or 443)' "$CONFIG/settings.json")
fi
[[ "$PORT" =~ ^[0-9]+$ ]] && ((PORT >= 1024 && PORT <= 65535)) || { echo '面板端口需为 1024–65535'; exit 2; }
[[ "$PORT" != 8306 && "$PORT" != 8308 && "$PORT" != 8311 ]] || { echo '8306、8308 和 8311 是内部服务保留端口'; exit 2; }
[[ -z "$TLS_CERT" && -z "$TLS_KEY" || -f "$TLS_CERT" && -f "$TLS_KEY" ]] || { echo '请同时提供有效的 --tls-cert 和 --tls-key 文件'; exit 2; }
[[ "$REF" =~ ^[A-Za-z0-9._/-]+$ ]] && [[ "$REF" != -* ]] || { echo '无效的 ref'; exit 2; }
[[ -f /etc/os-release ]] || { echo '无法识别系统'; exit 1; }
. /etc/os-release
case "$ID" in
  debian) [[ "${VERSION_ID%%.*}" -ge 12 ]] || { echo '需要 Debian 12+'; exit 1; };;
  ubuntu) [[ "${VERSION_ID%%.*}" -ge 22 ]] || { echo '需要 Ubuntu 22.04+'; exit 1; };;
  *) echo '引导安装暂支持 Debian/Ubuntu'; exit 1;;
esac
[[ -d /run/systemd/system ]] || { echo '需要以 systemd 启动的 VPS'; exit 1; }
case "$(uname -m)" in x86_64|aarch64);; *) echo '暂支持 amd64/arm64'; exit 1;; esac
FREE_KB=$(df -Pk /var | awk 'END {print $4}')
((FREE_KB >= 1048576)) || { echo '至少需要 1 GiB 可用空间'; exit 1; }
printf '系统：%s；面板端口：%s；/var 可用：%s KiB\n' "$PRETTY_NAME" "$PORT" "$FREE_KB"
if ((CHECK_ONLY)); then
  systemctl is-active sb-dashboard.service sb-manager.service sing-box.service xray.service || true
  command -v ss >/dev/null && ss -lntup | awk -v p=":$PORT" '$5 ~ p"$" {print}'
  echo '只读检查完成，未做修改。'
  exit 0
fi
((EUID == 0)) || { echo '请使用 sudo 或 root 执行'; exit 1; }
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq ca-certificates curl tar unzip openssl python3 python3-venv iproute2 iptables procps
if ! systemctl is-active --quiet sb-dashboard.service; then
  python3 - "$PORT" <<'PY'
import socket,sys
try:
    with socket.socket() as sock: sock.bind(('0.0.0.0', int(sys.argv[1])))
except OSError:
    raise SystemExit('面板端口已被占用，请使用 --port 和 --public-url 指定其他端口')
PY
fi
TMP=$(mktemp -d /tmp/sb-bootstrap.XXXXXX)
trap 'rm -rf -- "$TMP"' EXIT
trap 'echo "引导未完成。已有数据与凭据保留；如面板已启动，可登录后查看或重试。" >&2' ERR

if [[ -z "$SOURCE_DIR" ]]; then
  HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
  if [[ -f "$HERE/dashboard/manager.py" && -f "$HERE/sing-box.sh" ]]; then
    SOURCE_DIR=$HERE
  else
    curl -fL --retry 2 --connect-timeout 15 --max-time 180 \
      "https://codeload.github.com/$REPO/tar.gz/$REF" -o "$TMP/source.tar.gz"
    mkdir "$TMP/source"
    tar --extract --gzip --file "$TMP/source.tar.gz" --directory "$TMP/source" --strip-components=1 --no-same-owner
    SOURCE_DIR=$TMP/source
  fi
fi
SOURCE_DIR=$(cd -- "$SOURCE_DIR" && pwd)
for FILE in sing-box.sh dashboard/manager.py dashboard/panel/client_rules.py dashboard/core_download.py dashboard/xray_manager.py dashboard/xray_download.py dashboard/xray_firewall.py dashboard/vendor/xray-install/install-release.sh dashboard/app.py dashboard/admin.py dashboard/subscription_server.py dashboard/requirements.lock dashboard/static/app/index.html; do
  [[ -f "$SOURCE_DIR/$FILE" ]] || { echo "源码缺少 $FILE，请先发布完整 fork 或使用 --source-dir"; exit 1; }
done

getent group sb-dashboard >/dev/null || groupadd --system sb-dashboard
id sb-dashboard >/dev/null 2>&1 || useradd --system --gid sb-dashboard --home-dir "$DATA" --shell /usr/sbin/nologin sb-dashboard
install -d -m 755 "$PREFIX" "$PREFIX/releases"
install -d -m 750 -o root -g sb-dashboard "$CONFIG"
install -d -m 750 -o sb-dashboard -g sb-dashboard "$DATA"
install -d -m 700 /var/lib/sb-manager
install -d -m 750 -o root -g sb-dashboard /var/lib/sb-subscriptions
# Do not interrupt an in-flight configuration operation during a panel update.
python3 - <<'PY'
import json
from pathlib import Path
for file in Path('/var/lib/sb-manager/jobs').glob('*.json'):
    if json.loads(file.read_text()).get('state') in ('queued', 'running'):
        raise SystemExit('有管理任务尚未完成；请在网页确认完成后重试引导安装')
PY
if [[ -f "$CONFIG/settings.json" ]]; then
  # On rerun, preserve the original origin/port unless the operator explicitly changes it.
  [[ -n "$PUBLIC_URL" ]] || PUBLIC_URL=$(python3 -c 'import json;print(json.load(open("/etc/sb-dashboard/settings.json"))["site"]["public_url"])')
fi
if [[ -z "$PUBLIC_URL" ]]; then
  ADDRESS=$(curl -4 -fsS --max-time 10 https://api.ipify.org || curl -6 -fsS --max-time 10 https://api64.ipify.org || true)
  [[ -n "$ADDRESS" ]] || { echo '无法发现公网地址，请传入 --public-url'; exit 1; }
  [[ "$ADDRESS" != *:* ]] || ADDRESS="[$ADDRESS]"
  PUBLIC_URL="https://$ADDRESS:$PORT"
fi
export SB_BOOT_URL=$PUBLIC_URL SB_BOOT_PORT=$PORT SB_BOOT_ENGINE=$ENGINE SB_BOOT_NODE_PORT=$NODE_PORT SB_BOOT_REALITY_SNI=$REALITY_SNI
python3 - <<'PY'
import os
from urllib.parse import urlsplit
url=urlsplit(os.environ['SB_BOOT_URL'])
if (url.scheme!='https' or not url.hostname or url.username or url.password or url.path not in ('','/')
        or url.query or url.fragment or (url.port or 443)!=int(os.environ['SB_BOOT_PORT'])):
    raise SystemExit('--public-url 必须是 HTTPS 源，且端口与 --port 一致，不含路径/用户名/查询参数')
PY
RELEASE="$PREFIX/releases/$(date -u +%Y%m%d%H%M%S)-$$"
if [[ -f "$CONFIG/config.json" ]]; then
  BACKUP="/var/lib/sb-manager/bootstrap-backups/$(date -u +%Y%m%d%H%M%S)-$$"
  install -d -m 700 "$BACKUP"
  cp -a "$CONFIG/." "$BACKUP/"
  readlink "$PREFIX/current" > "$BACKUP/previous-release.txt" || true
fi
install -d -m 755 "$RELEASE"
cp "$SOURCE_DIR/sing-box.sh" "$RELEASE/sing-box.sh"
tar -C "$SOURCE_DIR" --exclude='dashboard/web/node_modules' --exclude='*/__pycache__' -cf - dashboard | tar -C "$RELEASE" -xf -
chown -R root:root "$RELEASE"
chmod -R go-w "$RELEASE"
[[ -x "$PREFIX/venv/bin/python" ]] || python3 -m venv "$PREFIX/venv"
"$PREFIX/venv/bin/pip" install --disable-pip-version-check -q -r "$RELEASE/dashboard/requirements.lock"
chmod -R a+rX "$PREFIX/venv"
if [[ -n "$TLS_CERT" ]]; then
  openssl x509 -in "$TLS_CERT" -noout >/dev/null
  openssl pkey -in "$TLS_KEY" -passin pass: -noout >/dev/null
  CERT_PUBLIC=$(openssl x509 -in "$TLS_CERT" -pubkey -noout | openssl pkey -pubin -outform DER | sha256sum)
  KEY_PUBLIC=$(openssl pkey -in "$TLS_KEY" -passin pass: -pubout -outform DER | sha256sum)
  [[ "$CERT_PUBLIC" == "$KEY_PUBLIC" ]] || { echo '证书与私钥不匹配'; exit 1; }
  install -m 640 -o root -g sb-dashboard "$TLS_CERT" "$CONFIG/tls.crt"
  install -m 640 -o root -g sb-dashboard "$TLS_KEY" "$CONFIG/tls.key"
fi

# Create a private account once. Reruns retain the password and all historical data.
"$PREFIX/venv/bin/python" - <<'PY'
import hashlib,ipaddress,json,os,secrets,subprocess
from pathlib import Path
from urllib.parse import urlsplit
root=Path('/etc/sb-dashboard'); url=os.environ['SB_BOOT_URL'].rstrip('/'); host=urlsplit(url).hostname
account=root/'config.json'
if account.exists():
    cfg=json.loads(account.read_text())
else:
    password=secrets.token_urlsafe(24); salt=secrets.token_hex(16)
    cfg={'username':'admin','salt':salt,'password_hash':hashlib.pbkdf2_hmac('sha256',password.encode(),bytes.fromhex(salt),600000).hex(),
         'api_secret':secrets.token_urlsafe(40),'origin_guard':secrets.token_hex(32)}
    account.write_text(json.dumps(cfg)); account.chmod(0o640)
    login=Path('/root/sb-dashboard-login.txt')
    login.write_text('账号：admin\n密码：'+password+'\n'); login.chmod(0o600)
manager_path=root/'manager.json'
manager=json.loads(manager_path.read_text()) if manager_path.exists() else {}
manager.update({'script':'/opt/sb-dashboard/current/sing-box.sh','socket':'/run/sb-manager/control.sock','group':'sb-dashboard',
         'data_dir':'/var/lib/sb-manager','monitor_config':'/var/lib/sb-dashboard/singbox-runtime.json',
         'api_address':'127.0.0.1:8306','api_secret':cfg['api_secret'],'server':host,'panel_port':int(os.environ['SB_BOOT_PORT']),
         'public_url':url,'subscription_dir':'/var/lib/sb-subscriptions'})
manager.update({'default_engine':os.environ['SB_BOOT_ENGINE'], 'settings_path':str(root/'settings.json'),
                'xray_monitor_config':'/var/lib/sb-dashboard/xray-runtime.json'})
(root/'manager.json').write_text(json.dumps(manager)); (root/'manager.json').chmod(0o600)
old_settings=json.loads((root/'settings.json').read_text()) if (root/'settings.json').exists() else {}
settings={'site':{'public_url':url,'base_path':'/monitor','title':'Sing-box 控制台','trust_proxy':False},
          'paths':{'data_dir':'/var/lib/sb-dashboard'},
          'singbox':{'config_path':manager['monitor_config'],'binary':'/etc/sing-box/sing-box','api_address':manager['api_address'],
                     'enabled':os.environ['SB_BOOT_ENGINE']!='xray' or Path('/etc/sing-box/conf').is_dir()},
          'management':{'enabled':True,'socket':manager['socket'],'subscription_dir':manager['subscription_dir']}, 'gate':{'enabled':False},
          'tls':{'cert_path':str(root/'tls.crt')},'alerts':{'services':['sing-box.service','sb-manager.service']}}
# Preserve optional upstream monitoring profiles and operator-selected probe targets.
for section in ('xray','reachability','probes','network','labels','entries'):
    if section in old_settings:
        settings[section]=old_settings[section]
if 'enabled' in old_settings.get('singbox', {}):
    settings['singbox']['enabled']=old_settings['singbox']['enabled']
settings['alerts'].update(old_settings.get('alerts', {}))
(root/'settings.json').write_text(json.dumps(settings,ensure_ascii=False)); (root/'settings.json').chmod(0o640)
cert=root/'tls.crt'; key=root/'tls.key'
if not cert.exists():
    try: ipaddress.ip_address(host); san='IP:'+host
    except ValueError: san='DNS:'+host
    subprocess.run(['openssl','req','-x509','-newkey','rsa:2048','-nodes','-days','365','-subj','/CN=Sing-box Dashboard',
                    '-addext','subjectAltName='+san,'-keyout',str(key),'-out',str(cert)],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    key.chmod(0o640); cert.chmod(0o640)
runtime=Path(manager['monitor_config'])
if not runtime.exists(): runtime.write_text('{}'); runtime.chmod(0o640)
print('面板地址：'+url+'/monitor/')
PY
chown root:sb-dashboard "$CONFIG/config.json" "$CONFIG/settings.json" "$CONFIG/tls.crt" "$CONFIG/tls.key"
chown root:sb-dashboard "$DATA/singbox-runtime.json"
ln -sfn "$RELEASE" "$PREFIX/current.new"
mv -Tf "$PREFIX/current.new" "$PREFIX/current"

cat > /etc/systemd/system/sb-manager.service <<UNIT
[Unit]
Description=Sing-box dashboard operation service
After=network-online.target
Wants=network-online.target
[Service]
Type=simple
User=root
Group=sb-dashboard
RuntimeDirectory=sb-manager
RuntimeDirectoryMode=0750
UMask=0077
ExecStartPre=/bin/bash $PREFIX/current/dashboard/panel-firewall.sh $PORT
ExecStart=/opt/sb-dashboard/venv/bin/python -B /opt/sb-dashboard/current/dashboard/manager.py
Restart=on-failure
RestartSec=3
TimeoutStopSec=20
[Install]
WantedBy=multi-user.target
UNIT
cat > /etc/systemd/system/sb-subscription.service <<UNIT
[Unit]
Description=Sing-box read-only subscription gateway (loopback)
After=network-online.target
[Service]
User=sb-dashboard
Group=sb-dashboard
WorkingDirectory=$PREFIX/current/dashboard
Environment=JOYSOL_CONFIG_DIR=$CONFIG
ExecStart=$PREFIX/venv/bin/python -B -m gunicorn --bind 127.0.0.1:8308 --workers 1 --threads 4 --timeout 30 --access-logfile /dev/null --error-logfile - 'subscription_server:create_app()'
Restart=on-failure
RestartSec=3
UMask=0077
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
[Install]
WantedBy=multi-user.target
UNIT
cat > /usr/local/bin/sb-dashboard-admin <<'UNIT'
#!/usr/bin/env bash
exec /opt/sb-dashboard/venv/bin/python -B /opt/sb-dashboard/current/dashboard/admin.py "$@"
UNIT
chmod 755 /usr/local/bin/sb-dashboard-admin
cat > /etc/systemd/system/sb-dashboard.service <<UNIT
[Unit]
Description=Sing-box HTTPS dashboard
After=network-online.target sb-manager.service
Wants=sb-manager.service
[Service]
User=sb-dashboard
Group=sb-dashboard
WorkingDirectory=$PREFIX/current/dashboard
Environment=JOYSOL_CONFIG_DIR=$CONFIG
ExecStart=$PREFIX/venv/bin/python -B -m gunicorn --bind 0.0.0.0:$PORT --workers 1 --worker-class gthread --threads 16 --timeout 60 --access-logfile /dev/null --error-logfile - --certfile $CONFIG/tls.crt --keyfile $CONFIG/tls.key app:app
Restart=on-failure
RestartSec=3
UMask=0077
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
ReadWritePaths=$DATA /run/xtables.lock
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_RAW
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_RAW
[Install]
WantedBy=multi-user.target
UNIT
touch /run/xtables.lock
chown root:sb-dashboard /run/xtables.lock
chmod 0660 /run/xtables.lock
install -d -m 755 /etc/tmpfiles.d
cat > /etc/tmpfiles.d/sb-dashboard.conf <<'UNIT'
f /run/xtables.lock 0660 root sb-dashboard -
UNIT
systemctl daemon-reload
systemctl enable sb-manager.service sb-dashboard.service sb-subscription.service >/dev/null
systemctl restart sb-manager.service sb-dashboard.service sb-subscription.service
for _ in $(seq 1 30); do
  if curl -kfsS --max-time 2 "https://127.0.0.1:$PORT/monitor/login" >/dev/null; then break; fi
  sleep 1
done
curl -kfsS --max-time 3 "https://127.0.0.1:$PORT/monitor/login" >/dev/null
printf '\n面板已启动：%s/monitor/\n查看登录账号密码：sudo cat /root/sb-dashboard-login.txt\n' "$PUBLIC_URL"
echo '首次证书为自签名；云平台安全组需放行面板 TCP 端口及节点端口。'
if ((!PANEL_ONLY)); then
  echo "部署内核：$ENGINE；已有本项目安装时保留节点。"
  "$PREFIX/venv/bin/python" - <<'PY'
import json,sys,time
import os
sys.path.insert(0,'/opt/sb-dashboard/current/dashboard')
from panel.management import call
sock='/run/sb-manager/control.sock'
engine=os.environ['SB_BOOT_ENGINE']
state,code=call(sock,'status',{'engine':engine})
if code!=200: raise SystemExit('任务服务不可用')
if engine=='xray' and state['installed']:
    from xray_manager import XrayManager
    from pathlib import Path
    manager=XrayManager(json.loads(Path('/etc/sb-dashboard/manager.json').read_text()))
    manager.export_monitor()
    manager.publish_subscriptions()
    print('保留已有 Xray 节点与服务状态，已刷新监控和订阅。')
    raise SystemExit(0)
if state['installed'] and __import__('pathlib').Path('/etc/sing-box/conf/09_dashboard_api.json').exists():
    from manager import Manager
    from pathlib import Path
    manager=Manager(json.loads(Path('/etc/sb-dashboard/manager.json').read_text()))
    manager.export_monitor()
    manager.publish_subscriptions()
    print('保留已有节点与服务状态，已刷新面板和订阅。')
    raise SystemExit(0)
op='adopt' if state['installed'] else 'install'
payload={'_actor':'bootstrap','engine':engine}
if engine=='xray': payload.update(name='xray',start_port=int(os.environ['SB_BOOT_NODE_PORT']),sni=os.environ['SB_BOOT_REALITY_SNI'])
data,code=call(sock,op,payload)
if code!=200: raise SystemExit(data.get('error','无法创建引导任务'))
job_id=data['job']['id']; seen=0
while True:
    state,code=call(sock,'status',{'engine':engine})
    job=next(j for j in state['jobs'] if j['id']==job_id)
    for event in job['events'][seen:]: print(event['message'],flush=True)
    seen=len(job['events'])
    if job['state'] not in ('queued','running'):
        if job['state']!='succeeded': raise SystemExit(job.get('error') or '引导任务未完成，请登录网页检查')
        break
    time.sleep(2)
PY
fi
echo '安装完成。后续在网页的“服务器管理”中操作。'
echo '导入节点：服务器管理 → 客户端配置与订阅 → 查看配置。没有域名时可下载配置文件导入。'
echo '忘记密码：sudo sb-dashboard-admin reset-password'
