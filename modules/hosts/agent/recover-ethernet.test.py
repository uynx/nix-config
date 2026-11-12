import os
from pathlib import Path
import subprocess
import tempfile
import unittest


class RecoveryTest(unittest.TestCase):
    def test_restores_adapter_without_changing_other_rules_or_store(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            rules = root / "etc/udev/rules.d/99-local.rules"
            rules.parent.mkdir(parents=True)
            original = root / "original.rules"
            original.write_text(
                'ACTION=="add", ATTR{vendor}=="0x1969", '
                'ATTR{device}=="0xe0b1", ATTR{remove}="1"\n'
                'SUBSYSTEM=="usb", MODE="0660"\n'
            )
            rules.symlink_to(original)
            rescan = root / "sys/bus/pci/rescan"
            rescan.parent.mkdir(parents=True)
            rescan.write_text("0\n")
            binaries = root / "bin"
            binaries.mkdir()
            for command in ("udevadm", "modprobe", "nmcli"):
                binary = binaries / command
                binary.write_text('#!/bin/sh\nprintf "%s\\n" "$0 $*"\n')
                binary.chmod(0o755)
            env = dict(os.environ, RECOVERY_ROOT=str(root))
            env["PATH"] = str(binaries) + os.pathsep + env["PATH"]
            for _ in range(2):
                subprocess.run(
                    ["bash", os.environ["RECOVERY_SCRIPT"]],
                    env=env, check=True, capture_output=True, text=True,
                )
                self.assertEqual(rules.read_text(), 'SUBSYSTEM=="usb", MODE="0660"\n')
                self.assertEqual(rescan.read_text(), "1\n")
            self.assertIn('ATTR{remove}="1"', original.read_text())
            self.assertFalse(rules.is_symlink())


if __name__ == "__main__":
    unittest.main()
