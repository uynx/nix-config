import importlib.util
import io
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location(
    'brave_vpn_tz', Path(__file__).with_name('brave_vpn_tz.py'))
tz = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tz)

HOME = 'America/New_York'


def lookup(exit_id):
    return {'de-fra-001': 'Europe/Berlin'}.get(exit_id)


class ZoneTest(unittest.TestCase):
    def test_vpn_off_uses_real_zone(self):
        status = {'vpnStatus': {'disconnected': {}}}
        self.assertEqual(tz.zone(status, HOME, lookup), HOME)

    def test_connected_uses_exit_zone(self):
        status = {'vpnStatus': {'connected': {'exit': {'id': 'de-fra-001'}}}}
        self.assertEqual(tz.zone(status, HOME, lookup), 'Europe/Berlin')

    def test_connecting_keeps_last_zone(self):
        status = {'vpnStatus': {'connecting': {'reconnecting': True}}}
        self.assertIsNone(tz.zone(status, HOME, lookup))

    def test_failed_lookup_keeps_last_zone(self):
        status = {'vpnStatus': {'connected': {'exit': {'id': 'xx-unk-9'}}}}
        self.assertIsNone(tz.zone(status, HOME, lookup))


class StreamTest(unittest.TestCase):
    def test_reads_pretty_printed_objects_one_by_one(self):
        stream = io.StringIO(
            '{\n  "version": "a",\n  "vpnStatus": {\n'
            '    "disconnected": {}\n  }\n}\n'
            '{\n  "version": "b",\n  "vpnStatus": {\n'
            '    "connecting": {}\n  }\n}\n')
        versions = [s['version'] for s in tz.statuses(stream)]
        self.assertEqual(versions, ['a', 'b'])


class RelaunchTest(unittest.TestCase):
    def test_reopens_every_profile_with_last_session(self):
        args = ['/x/brave-origin/brave', '--user-data-dir=/d',
                '--profile-directory=Default', '--no-pings',
                '--restore-last-session']
        self.assertEqual(tz.relaunch_args(args),
                         ['/x/brave-origin/brave', '--user-data-dir=/d',
                          '--no-pings', '--restore-last-session'])


if __name__ == '__main__':
    unittest.main()
