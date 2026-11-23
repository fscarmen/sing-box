"""Download an explicitly versioned official core and verify its release digest."""
import hashlib
import io
import json
import re
import tarfile
import urllib.request
from pathlib import Path


def download(version, arch, destination):
    if not re.fullmatch(r'1\.[0-9]+\.[0-9]+(?:-(?:alpha|beta|rc)\.[0-9]+)?', version) or arch not in ('amd64', 'arm64'):
        raise ValueError('无效的内核版本或架构')
    req = urllib.request.Request('https://api.github.com/repos/SagerNet/sing-box/releases/tags/v' + version,
                                 headers={'User-Agent': 'sing-box-dashboard-fixed'})
    with urllib.request.urlopen(req, timeout=30) as response:
        release = json.load(response)
    filename = 'sing-box-%s-linux-%s.tar.gz' % (version, arch)
    asset = next((a for a in release.get('assets', []) if a['name'] == filename), None)
    if not asset or not re.fullmatch(r'sha256:[a-f0-9]{64}', asset.get('digest', '')):
        raise ValueError('该版本没有可验证的官方 SHA256，请选择受支持版本')
    expected_url = 'https://github.com/SagerNet/sing-box/releases/download/v%s/%s' % (version, filename)
    if asset.get('browser_download_url') != expected_url:
        raise ValueError('官方内核下载地址不匹配')
    limit = 128 * 1024 * 1024
    with urllib.request.urlopen(expected_url, timeout=120) as response:
        archive = response.read(limit + 1)
    if len(archive) > limit or 'sha256:' + hashlib.sha256(archive).hexdigest() != asset['digest']:
        raise ValueError('内核 SHA256 校验失败，未安装')
    with tarfile.open(fileobj=io.BytesIO(archive)) as tar:
        member = tar.getmember('sing-box-%s-linux-%s/sing-box' % (version, arch))
        if not member.isfile() or not 0 < member.size <= limit:
            raise ValueError('官方内核压缩包内容无效')
        with tar.extractfile(member) as source:
            binary = source.read(limit + 1)
    destination = Path(destination)
    destination.write_bytes(binary)
    destination.chmod(0o755)
