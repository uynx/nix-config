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

    def vpn(self, arg):
        source = Path(__file__).with_name('default.nix').read_text()
        body = re.search(r"vpn\.body = ''(.*?)'';", source, re.S).group(1)
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            for name in ('sudo', 'obscura'):
                (root / name).write_text('#!/bin/sh\necho "' + name + ' $*" >> "$TRACE"\n')
                (root / name).chmod(0o755)
            env = dict(os.environ, TRACE=str(root / 'trace'), PATH=folder + ':' + os.environ['PATH'])
            subprocess.run(['fish', '-c', 'function vpn\n' + body + '\nend\nvpn ' + arg], env=env, check=True)
            return (root / 'trace').read_text().splitlines()

    def test_vpn_off_flags_before_stopping(self):
        trace = self.vpn('off')
        self.assertEqual(trace[0], 'sudo touch /var/lib/obscura-off')
        self.assertTrue(any(l.startswith('sudo systemctl stop obscura') for l in trace[1:]))

    def test_vpn_on_and_fix_clear_the_flag_first(self):
        for arg in ('on', 'fix'):
            self.assertEqual(self.vpn(arg)[0], 'sudo rm -f /var/lib/obscura-off')

    def test_units_skip_while_flagged(self):
        source = Path(__file__).with_name('default.nix').read_text()
        self.assertEqual(source.count('ConditionPathExists = "!/var/lib/obscura-off"'), 3)

    def test_activation_carries_old_run_flag(self):
        source = Path(__file__).with_name('default.nix').read_text()
        script = re.search(r"activationScripts\.obscuraOffFlag = ''(.*?)'';", source, re.S).group(1)
        for old_flag, expected in ((True, True), (False, False)):
            with tempfile.TemporaryDirectory() as folder:
                run, lib = Path(folder, 'run'), Path(folder, 'lib')
                run.mkdir(); lib.mkdir()
                if old_flag:
                    (run / 'obscura-off').touch()
                body = script.replace('/run/', f'{run}/').replace('/var/lib/', f'{lib}/')
                subprocess.run(['bash', '-euo', 'pipefail', '-c', body], check=True)
                self.assertEqual((lib / 'obscura-off').exists(), expected)

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
