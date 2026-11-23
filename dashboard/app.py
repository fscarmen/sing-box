"""Gunicorn entry point: `gunicorn app:app`. Configuration is described in panel/settings.py."""
from panel import create_app

app = create_app()
