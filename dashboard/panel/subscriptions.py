"""Read-only, token protected client downloads, separate from panel sessions."""
import hmac
import json
import os
import re
import secrets
import shutil
import tempfile
import time
import yaml
from pathlib import Path
from urllib.parse import urlsplit

from flask import Blueprint, Response, request
from . import client_rules

NODE_FORMATS = ('clash', 'clash2', 'proxies', 'shadowrocket', 'sing-box', 'v2rayn', 'throne')
FORMATS = NODE_FORMATS + client_rules.EXTRA_FORMATS


def validate_origin(value):
    value = str(value).strip().rstrip('/')
    try:
        url = urlsplit(value)
        port = url.port
        if (url.scheme != 'https' or not url.hostname or url.username or url.password
                or url.path or url.query or url.fragment or (port is not None and not 1 <= port <= 65535)
                or any(c.isspace() for c in value) or '\\' in value
                or not re.fullmatch(r'[A-Za-z0-9.:[\]-]+', url.netloc)):
            raise ValueError
    except (ValueError, TypeError):
        raise ValueError('订阅地址必须是 HTTPS 地址，例如 https://sub.example.com，不含路径或密钥')
    return value


def auto_format(agent, files):
    agent = agent.lower()
    if 'shadowrocket' in agent:
        name = 'shadowrocket'
    elif any(s in agent for s in ('sing-box', 'sfa', 'sfi', 'sfm')):
        name = 'sing-box'
    elif 'v2rayn' in agent:
        name = 'v2rayn'
    elif 'throne' in agent or 'neko' in agent:
        name = 'throne'
    else:
        # An inline Clash file works without a second provider request.
        name = 'clash2' if 'clash2' in files else 'clash'
    return name


def read_manifest(directory):
    try:
        return json.loads((Path(directory) / 'current' / 'manifest.json').read_text())
    except (OSError, ValueError):
        return {}


def publish(work, directory, origin, token, group=None):
    """Publish a whole export atomically; never change node addresses or Host/SNI."""
    origin = validate_origin(origin)
    if not re.fullmatch(r'[A-Za-z0-9_-]{32,128}', token):
        raise ValueError('无效订阅密钥')
    directory, work = Path(directory), Path(work)
    directory.mkdir(parents=True, exist_ok=True, mode=0o750)
    directory.chmod(0o750)
    gid = None
    if group:
        import grp
        gid = grp.getgrnam(group).gr_gid
        os.chown(directory, -1, gid)
    generation = Path(tempfile.mkdtemp(prefix='export-', dir=directory))
    generation.chmod(0o750)
    if gid is not None:
        os.chown(generation, -1, gid)
    files = []
    try:
        for name in NODE_FORMATS:
            source = work / 'subscribe' / name
            if not source.is_file() or source.is_symlink():
                continue
            text = source.read_text()
            if name in ('clash', 'clash2'):
                # Only replace provider URLs; proxy Host/SNI and credentials stay intact.
                text = re.sub(r'https?://[^\s\x22\x27<>]+/proxies(?=[\s\x22\x27]|$)',
                              origin + '/sub/' + token + '/proxies', text)
            dest = generation / name
            dest.write_text(text)
            dest.chmod(0o640)
            if gid is not None:
                os.chown(dest, -1, gid)
            files.append(name)
        manifest = {'origin': origin, 'token': token, 'files': files, 'updated': int(time.time())}
        dest = generation / 'manifest.json'
        dest.write_text(json.dumps(manifest))
        dest.chmod(0o640)
        if gid is not None:
            os.chown(dest, -1, gid)
        link = directory / ('.current-' + secrets.token_hex(8))
        link.symlink_to(generation.name)
        os.replace(link, directory / 'current')
    except Exception:
        shutil.rmtree(generation)
        raise
    # Retain a previous generation for requests already reading it.
    for old in sorted(directory.glob('export-*'), reverse=True, key=lambda p: p.stat().st_mtime)[3:]:
        if old.is_dir() and not old.is_symlink() and old != generation:
            shutil.rmtree(old)
    return manifest


def links(manifest):
    if not manifest.get('token'):
        return {}
    prefix = manifest['origin'] + '/sub/' + manifest['token'] + '/'
    return {name: prefix + name for name in ('auto',) + FORMATS if name == 'auto' or name in available_formats(manifest)}


def available_formats(manifest):
    files = list(manifest.get('files', []))
    return files + list(client_rules.EXTRA_FORMATS) if files else []


def content(current, manifest, name, policy):
    if name not in available_formats(manifest) or name not in FORMATS:
        raise ValueError('未提供此客户端格式')
    text = (Path(current) / name).read_text() if name in NODE_FORMATS else ''
    url = manifest['origin'] + '/sub/' + manifest['token'] + '/shadowrocket.conf'
    return client_rules.render(name, text, policy, url)


def bundle(directory, policy_directory=None):
    current = (Path(directory) / 'current').resolve()
    try:
        manifest = json.loads((current / 'manifest.json').read_text())
    except (OSError, ValueError):
        manifest = {}
    if not manifest: return {'files': {}, 'links': {}, 'origin': ''}
    policy = client_rules.load(policy_directory or directory)
    return {'files': {n: content(current, manifest, n, policy) for n in available_formats(manifest)},
            'links': links(manifest), 'origin': manifest['origin'], 'rules_revision': client_rules.revision(policy)}


def register(app, directory):
    bp = Blueprint('subscriptions', __name__)

    @bp.route('/sub/<token>/<name>', methods=['GET'])
    def download(token, name):
        # Resolve the generation once, so manifest and content come from one export.
        manifest = {}
        # Each core has an independent token and atomic export. Existing URLs stay valid.
        for root in (Path(directory), Path(directory) / 'xray'):
            current = (root / 'current').resolve()
            try:
                candidate = json.loads((current / 'manifest.json').read_text())
            except (OSError, ValueError):
                continue
            expected = candidate.get('token', '')
            if expected and hmac.compare_digest(token.encode(), expected.encode()):
                manifest = candidate
                break
        if not manifest:
            return '', 404
        if name == 'auto':
            name = auto_format(request.headers.get('User-Agent', ''), manifest['files'])
        if name not in FORMATS or name not in available_formats(manifest):
            return '', 404
        try:
            policy = client_rules.load(directory)
            body = content(current, manifest, name, policy)
        except (OSError, ValueError, TypeError, KeyError, yaml.YAMLError):
            return '', 503
        return Response(body, content_type='text/plain; charset=utf-8', headers={
            'Cache-Control': 'private, no-store, max-age=0', 'X-Content-Type-Options': 'nosniff',
            'Referrer-Policy': 'no-referrer', 'Profile-Update-Interval': '24',
            'X-Client-Rules-Revision': client_rules.revision(policy)})

    app.register_blueprint(bp)
