"""Pinned official Xray release ZIP, with GitHub SHA256 and archive validation."""
import hashlib
import io
import json
import re
import stat
import urllib.request
import zipfile
from pathlib import Path, PurePosixPath

DEFAULT_VERSION = '26.10.21'
LIMIT = 128 * 1024 * 1024


def download(version, arch, destination):
    if not re.fullmatch(r'(?:[0-9]{1,2}\.){2}[0-9]{1,2}', version) or arch not in ('amd64', 'arm64'):
        raise ValueError('请输入明确的 Xray 日期版本，例如 26.10.21')
    filename = 'Xray-linux-' + {'amd64': '64', 'arm64': 'arm64-v8a'}[arch] + '.zip'
    url = 'https://github.com/XTLS/Xray-core/releases/download/v' + version + '/' + filename
    req = urllib.request.Request('https://api.github.com/repos/XTLS/Xray-core/releases/tags/v' + version,
                                 headers={'User-Agent': 'sing-box-dashboard-fixed'})
    with urllib.request.urlopen(req, timeout=30) as response:
        release = json.load(response)
    asset = next((a for a in release.get('assets', []) if a['name'] == filename), {})
    digest = asset.get('digest', '')
    if asset.get('browser_download_url') != url or not re.fullmatch(r'sha256:[0-9a-f]{64}', digest):
        raise ValueError('没有可校验的官方 Xray 发布包')
    with urllib.request.urlopen(url, timeout=120) as response:
        archive = response.read(LIMIT + 1)
    if len(archive) > LIMIT or 'sha256:' + hashlib.sha256(archive).hexdigest() != digest:
        raise ValueError('Xray SHA256 校验失败，未安装')
    with zipfile.ZipFile(io.BytesIO(archive)) as source:
        members = source.infolist()
        if len(members) > 128 or sum(i.file_size for i in members) > LIMIT * 2:
            raise ValueError('Xray 压缩包内容过大')
        for info in members:
            path = PurePosixPath(info.filename)
            if (path.is_absolute() or '..' in path.parts or '\\' in info.filename
                    or stat.S_ISLNK(info.external_attr >> 16)):
                raise ValueError('Xray 压缩包路径无效')
        binary = source.getinfo('xray')
        if binary.is_dir() or not 0 < binary.file_size <= LIMIT:
            raise ValueError('Xray 压缩包缺少有效内核')
        content = source.read(binary)
    destination = Path(destination)
    destination.write_bytes(archive)
    Path(str(destination) + '.dgst').write_text('SHA256=' + digest.split(':', 1)[1] + '\n')
    candidate = destination.parent / 'xray'
    candidate.write_bytes(content)
    candidate.chmod(0o755)
    return candidate
