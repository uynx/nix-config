"""Created for project [[nix]]"""
import os
import pty
import shutil
import signal
import socket
import stat
import subprocess
import sys
import tempfile
import termios
import threading
import time
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import terms  # noqa: E402

HOST = os.uname().nodename.split(".")[0]


def pane(sock, pid, cmd, cwd):
    return {"sock": sock, "id": pid, "cmd": cmd, "cwd": cwd}


class Names(unittest.TestCase):
    def names(self, panes):
        terms.name_all(panes, "asahi", "/home/u")
        return [p["name"] for p in panes]

    def test_host_folder_program(self):
        self.assertEqual(
            self.names([pane("term", "%0", "claude", "/home/u/nix-config")]),
            ["asahi-nix-config-claude"],
        )

    def test_home_and_root(self):
        self.assertEqual(
            self.names([
                pane("term", "%0", "fish", "/home/u"),
                pane("term", "%1", "fish", "/"),
            ]),
            ["asahi-home-fish", "asahi-root-fish"],
        )

    def test_nix_wrapper_and_odd_characters(self):
        self.assertEqual(
            self.names([pane("term", "%0", ".yazi-wrapped", "/x/my dir (1)")]),
            ["asahi-my_dir_1_-yazi"],
        )

    def test_twins_take_their_pane_number(self):
        self.assertEqual(
            self.names([
                pane("term", "%3", "claude", "/home/u/dotfiles"),
                pane("term", "%7", "claude", "/home/u/dotfiles"),
                pane("term", "%8", "nvim", "/home/u/dotfiles"),
            ]),
            [
                "asahi-dotfiles-claude-3",
                "asahi-dotfiles-claude-7",
                "asahi-dotfiles-nvim",
            ],
        )

    def test_twins_on_other_sockets_take_the_socket_too(self):
        self.assertEqual(
            self.names([
                pane("lane3", "%0", "claude", "/home/u/pm"),
                pane("lane4", "%0", "claude", "/home/u/pm"),
            ]),
            ["asahi-pm-claude-lane3-0", "asahi-pm-claude-lane4-0"],
        )


class Rig(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="terms"))
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)
        self.bin = self.tmp / "bin"
        self.bin.mkdir()
        self.env = {
            **os.environ,
            "TMUX_TMPDIR": str(self.tmp),
            "HOME": str(self.tmp / "home"),
            "PATH": f"{self.bin}:{os.environ['PATH']}",
        }
        self.env.pop("TMUX", None)
        self.env.pop("TERMS_HOSTS", None)
        self.socks = set()

    def tearDown(self):
        for sock in self.socks:
            subprocess.run(
                ["tmux", "-L", sock, "kill-server"],
                env=self.env, capture_output=True,
            )

    def session(self, sock, folder, command):
        cwd = self.tmp / folder
        cwd.mkdir(parents=True, exist_ok=True)
        self.socks.add(sock)
        subprocess.run(
            ["tmux", "-f", "/dev/null", "-L", sock, "new-session", "-d",
             "-x", "80", "-y", "24", "-c", str(cwd), command],
            env=self.env, check=True,
        )
        return cwd

    def terms(self, *args, text=None):
        return subprocess.run(
            [sys.executable, str(HERE / "terms.py"), *args],
            env=self.env, input=text, capture_output=True, text=True,
        )

    def settled(self):
        last = None
        for _ in range(50):
            time.sleep(0.2)
            now = self.terms("--local").stdout
            if now and now == last and "-tmux " not in now:
                return now
            last = now
        self.fail(f"listing never settled: {last}")

    def only(self):
        return self.settled().split()[0]

    def wait_for(self, path):
        for _ in range(50):
            if path.exists() and path.read_text():
                return path.read_text()
            time.sleep(0.1)
        self.fail(f"{path} never written")

    def fake_ssh(self, body):
        ssh = self.bin / "ssh"
        ssh.write_text("#!/bin/sh\n" + body)
        ssh.chmod(ssh.stat().st_mode | stat.S_IXUSR)

    def until(self, check, what):
        for _ in range(80):
            if check():
                return
            time.sleep(0.1)
        self.fail(what() if callable(what) else what)


class Cli(Rig):
    def test_list_names_every_pane_on_every_socket(self):
        work = self.session("term", "work", "sleep 600")
        self.session("lane3", "home", "sleep 600")
        out = self.settled()
        self.assertIn(f"{HOST}-work-sleep", out)
        self.assertIn(f"{HOST}-home-sleep", out)
        self.assertIn(str(work), out)
        self.assertEqual(len(out.splitlines()), 2)

    def test_dead_sockets_are_passed_over(self):
        self.session("term", "work", "sleep 600")
        root = self.tmp / f"tmux-{os.getuid()}"
        (root / "junk").write_text("")
        self.session("gone", "work", "sleep 600")
        subprocess.run(["tmux", "-L", "gone", "kill-server"], env=self.env)
        socket.socket(socket.AF_UNIX).bind(str(root / "stale"))
        self.assertEqual(self.only(), f"{HOST}-work-sleep")

    def test_show_prints_the_screen(self):
        self.session("term", "work", "sh -c 'echo MARKER-42; sleep 600'")
        r = self.terms("--local", "show", self.only())
        self.assertEqual(r.stdout.strip(), "MARKER-42")

    def test_send_types_the_text_and_enter(self):
        cwd = self.session(
            "term", "work", "sh -c 'IFS= read -r x; printf %s \"$x\" > out'")
        text = "it's a \\ $HOME \"test\""
        r = self.terms("--local", "send", self.only(), text)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(self.wait_for(cwd / "out"), text)

    def test_send_reads_stdin_for_a_dash(self):
        cwd = self.session(
            "term", "work", "sh -c 'IFS= read -r x; printf %s \"$x\" > out'")
        self.terms("--local", "send", self.only(), "-", text="a\\b")
        self.assertEqual(self.wait_for(cwd / "out"), "a\\b")

    def test_keys_presses_named_keys(self):
        cwd = self.session(
            "term", "work", "sh -c 'IFS= read -r x; printf %s \"$x\" > out'")
        self.terms("--local", "keys", self.only(), "h", "i", "Enter")
        self.assertEqual(self.wait_for(cwd / "out"), "hi")

    def test_unknown_name_fails_and_lists_the_real_ones(self):
        self.session("term", "work", "sleep 600")
        self.settled()
        r = self.terms("--local", "show", f"{HOST}-nope-fish")
        self.assertNotEqual(r.returncode, 0)
        self.assertIn(f"{HOST}-work-sleep", r.stderr)

    def test_list_without_hosts_is_an_error(self):
        r = self.terms()
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("TERMS_HOSTS", r.stderr)

    def test_list_merges_other_hosts_and_marks_dead_ones(self):
        self.session("term", "work", "sleep 600")
        self.settled()
        self.fake_ssh(
            'for a; do h=$a; [ "$a" = terms ] && break; p=$a; done\n'
            '[ "$p" = down.lan ] && exit 255\n'
            'echo "otherbox-pm-claude  ~/pm  2m  title"\n')
        self.env["TERMS_HOSTS"] = f"{HOST}.lan otherbox.lan down.lan"
        r = self.terms()
        self.assertEqual(r.returncode, 0, r.stderr)
        lines = r.stdout.splitlines()
        self.assertEqual(len(lines), 3, r.stdout)
        self.assertIn(f"{HOST}-work-sleep", lines[0])
        self.assertIn("otherbox-pm-claude", lines[1])
        self.assertEqual(lines[2], "down: unreachable")

    def test_send_to_another_host_goes_over_ssh_with_text_on_stdin(self):
        self.fake_ssh(
            f'echo "$@" > {self.tmp}/argv\ncat > {self.tmp}/stdin\n')
        self.env["TERMS_HOSTS"] = f"{HOST}.lan otherbox.lan"
        r = self.terms("send", "otherbox-pm-claude", "a\\b 'c'")
        self.assertEqual(r.returncode, 0, r.stderr)
        argv = (self.tmp / "argv").read_text().strip()
        self.assertTrue(
            argv.endswith(
                "otherbox.lan terms --local send otherbox-pm-claude -"),
            argv)
        self.assertEqual((self.tmp / "stdin").read_text(), "a\\b 'c'")


@unittest.skipUnless("TERM_TMUX" in os.environ, "needs the configured tmux")
class Windows(Rig):
    def setUp(self):
        super().setUp()
        self.home = Path(self.env["HOME"])
        self.home.mkdir()
        self.env.update(TERM="xterm-256color", SHELL="/bin/sh")
        self.socks.update(("term", "default"))

    def open_window(self):
        master, slave = pty.openpty()
        termios.tcsetwinsize(slave, (24, 80))
        client = subprocess.Popen(
            [os.environ["TERM_TMUX"], "-L", "term", "new-session"],
            stdin=slave, stdout=slave, stderr=slave, env=self.env,
            cwd=self.home, start_new_session=True)
        os.close(slave)

        def drain():
            try:
                while os.read(master, 65536):
                    pass
            except OSError:
                pass

        threading.Thread(target=drain, daemon=True).start()
        self.addCleanup(client.kill)
        self.until(lambda: self.listed(), "the window never showed up")
        return client

    def listed(self):
        return self.terms("--local").stdout.splitlines()

    def option(self, sock, name):
        return subprocess.run(
            [os.environ["TERM_TMUX"], "-L", sock, "start-server", ";",
             "show", "-gqv", name],
            env=self.env, capture_output=True, text=True).stdout.strip()

    def test_window_is_named_bare_and_dies_when_closed(self):
        client = self.open_window()
        self.assertEqual(self.only(), f"{HOST}-home-sh")
        self.assertEqual(self.option("term", "status"), "off")
        client.send_signal(signal.SIGHUP)
        self.until(lambda: not self.listed(), "the session outlived it")

    def test_only_other_sockets_save_and_restore(self):
        self.assertEqual(
            self.option("term", "@resurrect-restore-script-path"), "")
        self.assertIn(
            "restore.sh",
            self.option("default", "@resurrect-restore-script-path"))

    @unittest.skipUnless("TERM_SESSIONIZER" in os.environ, "needs it built")
    def test_sessionizer_moves_the_window_to_the_saved_server(self):
        project = self.tmp / "my project"
        project.mkdir()
        self.env["_ZO_DATA_DIR"] = str(self.tmp / "zo")
        subprocess.run(["zoxide", "add", str(project)],
                       env=self.env, check=True)
        self.open_window()
        name = self.only()
        self.terms("--local", "send", name, os.environ["TERM_SESSIONIZER"])

        def screen():
            return self.terms("--local", "show", self.only()).stdout

        self.until(lambda: "1/1" in screen(), screen)
        self.terms("--local", "keys", self.only(), "Enter")

        def attached():
            return subprocess.run(
                ["tmux", "-L", "default", "list-clients", "-F",
                 "#{session_name}"],
                env=self.env, capture_output=True, text=True).stdout.strip()

        self.until(lambda: attached() == "my project", screen)
        self.assertEqual(self.only(), f"{HOST}-my_project-sh")


if __name__ == "__main__":
    unittest.main()
