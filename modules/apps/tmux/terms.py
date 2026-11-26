#!/usr/bin/env python3
"""Created for project [[nix]]

terms                         every terminal on every machine in TERMS_HOSTS
terms show NAME [LINES]       print its screen, plus LINES of scrollback
terms send NAME TEXT          type TEXT and press Enter ("-" reads stdin)
terms keys NAME KEY...        press tmux keys: Enter Escape C-c Up 1 ...
terms --local [...]           this machine only

A name is host-label when the pane has a tmux @label (tmux set -p @label X),
else host-folder-program, which also stays valid. Twins carry their pane number.
"""
import os
import re
import socket
import subprocess
import sys
import time
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

HOST = os.uname().nodename.split(".")[0]
FIELDS = ("pane_id", "pane_current_command", "pane_current_path",
          "window_activity", "pane_title", "@label")
FMT = "\t".join("#{%s}" % f for f in FIELDS)


def tmux(sock, *args):
    return subprocess.run(["tmux", "-L", sock, *args],
                          capture_output=True, text=True)


def alive(path):
    with socket.socket(socket.AF_UNIX) as s:
        try:
            s.connect(str(path))
        except OSError:
            return False
    return True


def panes():
    # tmux's own socket rule, not a project path
    root = Path(os.environ.get("TMUX_TMPDIR", "/tmp")) / f"tmux-{os.getuid()}"
    found = []
    for sock in sorted(p.name for p in root.glob("*") if alive(p)):
        for line in tmux(sock, "list-panes", "-a", "-F", FMT).stdout.splitlines():
            pid, cmd, cwd, active, title, label = line.split("\t", 5)
            found.append({"sock": sock, "id": pid, "cmd": cmd, "cwd": cwd,
                          "active": int(active), "title": title, "label": label})
    name_all(found, HOST, os.environ["HOME"])
    return found


def name_all(found, host, home):
    for p in found:
        folder = "home" if p["cwd"] == home else Path(p["cwd"]).name or "root"
        prog = p["cmd"].lstrip(".").removesuffix("-wrapped")
        slug = lambda s: re.sub(r"[^\w.-]+", "_", f"{host}-{s}")
        p["legacy"] = slug(f"{folder}-{prog}")
        p["name"] = slug(p["label"]) if p.get("label") else p["legacy"]
    twins = Counter(p["name"] for p in found)
    for p in found:
        if twins[p["name"]] > 1:
            sock = "" if p["sock"] == "term" else "-" + p["sock"]
            p["name"] += f"{sock}-{p['id'].lstrip('%')}"


def ago(seconds):
    for size, unit in ((86400, "d"), (3600, "h"), (60, "m")):
        if seconds >= size:
            return f"{seconds // size}{unit}"
    return f"{seconds}s"


def listing():
    found = panes()
    width = max((len(p["name"]) for p in found), default=0)
    home = os.environ["HOME"]
    now = int(time.time())
    return "".join(
        "{}  {}  {}  {}\n".format(
            p["name"].ljust(width),
            p["cwd"].replace(home, "~", 1) if p["cwd"].startswith(home)
            else p["cwd"],
            ago(now - p["active"]), p["title"])
        for p in found)


def find(name):
    found = panes()
    for p in found:
        if name in (p["name"], p["legacy"]):
            return p
    sys.exit(f"no terminal named {name}; here: "
             + (" ".join(p["name"] for p in found) or "none"))


def local(args):
    if not args:
        sys.stdout.write(listing())
        return
    verb, name, rest = args[0], args[1], args[2:]
    p = find(name)
    if rest == ["-"]:
        rest = [sys.stdin.read()] if verb == "send" else sys.stdin.read().split()
    if verb == "show":
        lines = rest[0] if rest else "0"
        out = tmux(p["sock"], "capture-pane", "-p", "-J", "-t", p["id"],
                   "-S", f"-{lines}").stdout
        print(out.rstrip("\n"))
    elif verb == "send":
        tmux(p["sock"], "send-keys", "-t", p["id"], "-l", "--", rest[0])
        time.sleep(0.3)
        tmux(p["sock"], "send-keys", "-t", p["id"], "Enter")
    elif verb == "keys":
        tmux(p["sock"], "send-keys", "-t", p["id"], *rest)
    else:
        sys.exit(__doc__)


def ssh(host, args, text=""):
    return subprocess.run(
        ["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=8", host,
         "terms", "--local", *args],
        input=text or "", capture_output=True, text=True,
        env={**os.environ, "SSH_ASKPASS_REQUIRE": "never"})


def everywhere(hosts):
    def one(host):
        short = host.split(".")[0]
        if short == HOST:
            return listing()
        r = ssh(host, [])
        return r.stdout if r.returncode == 0 else f"{short}: unreachable\n"

    with ThreadPoolExecutor(len(hosts)) as pool:
        sys.stdout.write("".join(pool.map(one, hosts)))


def main(args):
    if args[:1] == ["--local"]:
        return local(args[1:])
    if args and (args[0] not in ("show", "send", "keys") or len(args) < 2):
        sys.exit(__doc__)
    if "TERMS_HOSTS" not in os.environ:
        sys.exit("TERMS_HOSTS is not set; use --local for this machine")
    hosts = os.environ["TERMS_HOSTS"].split()
    if not args:
        return everywhere(hosts)
    verb, name, rest = args[0], args[1], args[2:]
    for host in hosts:
        short = host.split(".")[0]
        if short != HOST and name.startswith(short + "-"):
            text = None
            if verb in ("send", "keys") and rest != ["-"]:
                text = rest[0] if verb == "send" else "\n".join(rest)
                rest = ["-"]
            elif rest == ["-"]:
                text = sys.stdin.read()
            r = ssh(host, [verb, name, *rest], text)
            sys.stdout.write(r.stdout)
            sys.stderr.write(r.stderr)
            sys.exit(r.returncode)
    local(args)


if __name__ == "__main__":
    main(sys.argv[1:])
