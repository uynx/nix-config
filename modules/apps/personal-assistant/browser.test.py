import os
from pathlib import Path
import re
import subprocess
import tempfile
import time
import unittest

STUBS = {
    'sudo': '#!/bin/sh\n[ "$1" = -E ] && shift\nexec "$@"\n',
    'ip': '#!/bin/sh\nif [ "$1" = link ]; then [ "$VPN" = on ]; exit; fi\nshift 3\nNETNS=1 exec "$@"\n',
    'wg': '#!/bin/sh\nprintf "key\\t%s\\n" "$HS"\n',
    'runuser': '#!/bin/sh\nwhile [ "$1" != -- ]; do shift; done\nshift\nexec "$@"\n',
    'systemctl': '#!/bin/sh\necho "systemctl $*" >> "$TRACE"\n',
    'python3': '#!/bin/sh\necho "python3 netns=${NETNS:-0} $*" >> "$TRACE"\n',
}


def browse(vpn, handshake_age):
    source = Path(__file__).with_name('default.nix').read_text()
    body = re.search(r'writeShellScriptBin "assistant-browser" \'\'(.*?)\'\';', source, re.S).group(1)
    body = re.sub(r'\$\{[^}]*\}/bin/', '', body).replace('/run/wrappers/bin/', '').replace("''$", '$')
    with tempfile.TemporaryDirectory() as folder:
        root = Path(folder)
        for name, text in STUBS.items():
            (root / name).write_text(text)
            (root / name).chmod(0o755)
        env = dict(os.environ, VPN=vpn, HS=str(int(time.time()) - handshake_age if handshake_age is not None else 0),
                   TRACE=str(root / 'trace'), PATH=folder + ':' + os.environ['PATH'])
        subprocess.run(['sh', '-c', body, 'assistant-browser', 'run', 'x.py'], env=env, check=True)
        return (root / 'trace').read_text().splitlines()


class BrowserRouteTest(unittest.TestCase):
    def test_live_tunnel_and_host_vpn_off_uses_the_tunnel(self):
        trace = browse('off', 30)
        self.assertIn('systemctl --user start personal-assistant-browser', trace)
        self.assertTrue(trace[-1].startswith('python3 netns=1 '))
        self.assertTrue(trace[-1].endswith('ab.py run x.py'))

    def test_host_vpn_connected_goes_direct(self):
        trace = browse('on', 30)
        self.assertIn('systemctl --user start personal-assistant-browser-direct', trace)
        self.assertTrue(trace[-1].startswith('python3 netns=0 '))

    def test_dead_tunnel_goes_direct(self):
        for age in (1000, None):
            trace = browse('off', age)
            self.assertIn('systemctl --user stop personal-assistant-browser', trace)
            self.assertTrue(trace[-1].startswith('python3 netns=0 '))


if __name__ == '__main__':
    unittest.main()
