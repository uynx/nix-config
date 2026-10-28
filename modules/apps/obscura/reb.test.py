import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest


class RebuildVpnTest(unittest.TestCase):
    def check_state(self, before, reconnect):
        source = Path(__file__).with_name('default.nix').read_text()
        def hook(name):
            match = re.search(rf'{name} = \'\'(.*?)\'\';', source, re.S)
            return match.group(1) if match else ''
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            commands = {
                'sudo': '#!/bin/sh\nexec "$@"\n',
                'systemctl': '#!/bin/sh\nif [ "$1" = is-active ]; then [ "$BEFORE" != off ]; elif [ "$1" = stop ]; then echo stop >> "$TRACE"; else echo 123; fi\n',
                'ps': '#!/bin/sh\nprintf "%s service\\n" "$FIXTURE/obscura"\n',
                'obscura': '#!/bin/sh\nif [ "$1" = status ]; then if [ "$BEFORE" = unavailable ]; then exit 1; elif [ "$BEFORE" = on ]; then echo "VPN is connected to test."; else echo "VPN is disconnected."; fi; else echo connect >> "$TRACE"; fi\n',
                'obscura-connect-denver': '#!/bin/sh\necho connect >> "$TRACE"\n',
            }
            for name, body in commands.items():
                path = root / name
                path.write_text(body)
                path.chmod(0o755)
            env = dict(os.environ, BEFORE=before, FIXTURE=folder, TRACE=str(root / 'trace'), PATH=folder + ':' + os.environ['PATH'])
            result = subprocess.run(['fish', '-c', 'function fixture\n' + hook('rebSnapshot') + '\n' + hook('rebPostSwitch') + '\nend\nfixture'], env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            actual = (root / 'trace').read_text() if (root / 'trace').exists() else ''
            self.assertEqual('connect' in actual, reconnect)
            return actual

    def test_off_stays_off(self):
        self.check_state('off', False)

    def test_on_reconnects(self):
        self.check_state('on', True)

    def test_disconnected_daemon_stays_off(self):
        self.check_state('disconnected', False)

    def test_unavailable_status_does_not_change_vpn(self):
        self.assertNotIn('stop', self.check_state('unavailable', False))


if __name__ == '__main__':
    unittest.main()
