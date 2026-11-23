"""Loopback-only subscription gateway for a fixed domain / Cloudflare Tunnel.

No dashboard, database, login, management API or firewall is loaded here.
"""
from flask import Flask
from panel import settings
from panel.subscriptions import register


def create_app():
    config = settings.load()
    app = Flask(__name__, static_folder=None)
    register(app, config.get('management.subscription_dir', str(config.data_dir / 'subscriptions')))
    return app
