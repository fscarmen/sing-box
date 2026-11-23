"""Authenticated web adapter for the local, independently supervised task service."""
import http.client
import json
import socket
import time

from flask import jsonify, request


class LocalConnection(http.client.HTTPConnection):
    def __init__(self, path):
        super().__init__('localhost', timeout=15)
        self.path = path

    def connect(self):
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.settimeout(self.timeout)
        self.sock.connect(self.path)


def call(path, operation, payload=None):
    connection = LocalConnection(path)
    try:
        body = json.dumps({'operation': operation, 'payload': payload or {}})
        connection.request('POST', '/', body, {'Content-Type': 'application/json'})
        response = connection.getresponse()
        data = json.loads(response.read(4 * 1024 * 1024))
        return data, response.status
    finally:
        connection.close()


def register(bp, ctx):
    @bp.route('/api/manage/<operation>', methods=['GET', 'POST'])
    def manage(operation):
        settings = ctx.settings
        if not settings.get('management.enabled', False):
            return jsonify(error='此部署未启用服务器管理'), 404
        # Additional monitoring accounts do not acquire root operations or node secrets.
        if request.joysol_session['user'] != settings.secrets['username']:
            return jsonify(error='仅主管理员可管理服务器'), 403
        reads = ('status', 'config', 'subscriptions', 'rules')
        writes = ('install', 'apply', 'adopt', 'start', 'stop', 'restart', 'backup', 'restore', 'export', 'upgrade', 'subscription', 'rules-save')
        if operation not in (reads if request.method == 'GET' else writes):
            return jsonify(error='不支持的操作或请求方法'), 405
        payload = request.get_json(silent=True) if request.method == 'POST' else {'engine': request.args.get('engine', 'singbox')}
        if not isinstance(payload, dict):
            return jsonify(error='参数必须是对象'), 400
        payload['_actor'] = request.joysol_session['user']
        try:
            data, status = call(settings.get('management.socket'), operation, payload)
        except (OSError, ValueError, http.client.HTTPException):
            return jsonify(error='任务服务暂不可用，请稍后重试'), 503
        if request.method == 'POST' and status == 200:
            with ctx.store.write() as c:
                c.execute('INSERT INTO audit VALUES(?,?,?,?)', (int(time.time()), 'manage:' + operation,
                          request.remote_addr or '', data['job']['id']))
        return jsonify(data), status
