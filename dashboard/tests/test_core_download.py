import hashlib
import io
import json
import tarfile
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from helpers import ORIGIN  # ensure dashboard is on the import path
from core_download import download


class CoreDownloadTests(unittest.TestCase):
    def test_digest_failure_never_writes_executable(self):
        asset = {'name': 'sing-box-1.14.3-linux-amd64.tar.gz', 'digest': 'sha256:' + '0' * 64,
                 'browser_download_url': 'https://github.com/SagerNet/sing-box/releases/download/v1.14.3/sing-box-1.14.3-linux-amd64.tar.gz'}
        with tempfile.TemporaryDirectory() as tmp, patch('core_download.urllib.request.urlopen', side_effect=[
                io.BytesIO(json.dumps({'assets': [asset]}).encode()), io.BytesIO(b'untrusted')]):
            destination = Path(tmp) / 'sing-box'
            with self.assertRaisesRegex(ValueError, 'SHA256'):
                download('1.14.3', 'amd64', destination)
            self.assertFalse(destination.exists())

    def test_verified_archive_extracts_only_the_named_regular_binary(self):
        output = io.BytesIO()
        with tarfile.open(fileobj=output, mode='w:gz') as tar:
            content = b'test-core'
            info = tarfile.TarInfo('sing-box-1.14.3-linux-amd64/sing-box'); info.size = len(content)
            tar.addfile(info, io.BytesIO(content))
        archive = output.getvalue()
        asset = {'name': 'sing-box-1.14.3-linux-amd64.tar.gz', 'digest': 'sha256:' + hashlib.sha256(archive).hexdigest(),
                 'browser_download_url': 'https://github.com/SagerNet/sing-box/releases/download/v1.14.3/sing-box-1.14.3-linux-amd64.tar.gz'}
        with tempfile.TemporaryDirectory() as tmp, patch('core_download.urllib.request.urlopen', side_effect=[
                io.BytesIO(json.dumps({'assets': [asset]}).encode()), io.BytesIO(archive)]):
            destination = Path(tmp) / 'sing-box'
            download('1.14.3', 'amd64', destination)
            self.assertEqual(destination.read_bytes(), content)
            self.assertEqual(destination.stat().st_mode & 0o777, 0o755)
