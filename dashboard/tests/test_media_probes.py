import unittest
from unittest.mock import patch
from panel import probes, settings


class MediaProbeTests(unittest.TestCase):
    def test_media_http_statuses_do_not_invent_exit_ip(self):
        for status, ok in [(200, 1), (204, 1), (302, 1), (403, 0), (429, 0), (500, 0)]:
            with self.subTest(status=status), patch.object(probes, 'fetch', return_value=(status, 'ip=203.0.113.1', 2, 3)):
                r = probes.probe({'name': 'media', 'url': 'https://example.com', 'kind': 'http'})
                self.assertEqual(r['ok'], ok)
                self.assertEqual(r['exit_ip'], '')

    def test_trace_still_requires_valid_echo(self):
        for body, ok in [('hello', 0), ('ip=invalid', 0), ('ip=203.0.113.1', 1)]:
            with patch.object(probes, 'fetch', return_value=(200, body, 2, 3)):
                self.assertEqual(probes.probe({'name': 'trace', 'url': 'https://example.com'})['ok'], ok)

    def test_defaults_use_media_and_keep_trace(self):
        targets = settings.DEFAULTS['probes']['targets']
        self.assertEqual([t['name'] for t in targets], ['trace', 'Instagram', 'YouTube', 'Facebook'])


if __name__ == '__main__':
    unittest.main()
