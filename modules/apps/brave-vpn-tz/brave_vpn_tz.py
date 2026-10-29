import json
import os
import signal
import subprocess
import time
import urllib.request

DATA = os.path.expanduser('~/.config/BraveSoftware/Brave-Browser')


def zone(status, home, exit_zone):
    vpn = status['vpnStatus']
    if 'disconnected' in vpn:
        return home
    if 'connected' in vpn:
        return exit_zone(vpn['connected']['exit']['id'])
    return None


def statuses(stream):
    buf = ''
    for line in stream:
        buf += line
        try:
            status = json.loads(buf)
        except ValueError:
            continue
        buf = ''
        yield status


def relaunch_args(args):
    drop = ('--profile-directory=', '--restore-last-session')
    return [a for a in args if not a.startswith(drop)] + [drop[1]]


def brave():
    for pid in filter(str.isdigit, os.listdir('/proc')):
        try:
            with open(f'/proc/{pid}/cmdline', 'rb') as f:
                args = f.read().decode().split('\0')[:-1]
            with open(f'/proc/{pid}/environ', 'rb') as f:
                env = f.read().decode().split('\0')
        except OSError:
            continue
        if (args and args[0].endswith('/brave-origin/brave')
                and f'--user-data-dir={DATA}' in args
                and not any(a.startswith('--type=') for a in args)):
            tz = next((e[3:] for e in env if e.startswith('TZ=')), None)
            return int(pid), args, tz
    return None, None, None


def apply(tz, home, state):
    with open(state + '.tmp', 'w') as f:
        f.write(tz)
    os.replace(state + '.tmp', state)
    pid, args, running = brave()
    if pid is None or (running or home) == tz:
        return
    os.kill(pid, signal.SIGTERM)
    for _ in range(150):
        if not os.path.exists(f'/proc/{pid}'):
            break
        time.sleep(0.2)
    else:
        return
    subprocess.run(['systemd-run', '--user', '--collect', '--quiet',
                    f'--setenv=TZ={tz}', '--', *relaunch_args(args)])


def main():
    from timezonefinder import TimezoneFinder
    finder = TimezoneFinder()
    cache = {}

    def exit_zone(exit_id):
        if exit_id not in cache:
            try:
                url = 'https://am.i.mullvad.net/json'
                with urllib.request.urlopen(url, timeout=10) as r:
                    geo = json.load(r)
                cache[exit_id] = finder.timezone_at(
                    lng=geo['longitude'], lat=geo['latitude'])
            except (OSError, ValueError, KeyError):
                return None
        return cache[exit_id]

    home = os.path.realpath('/etc/localtime').split('zoneinfo/')[1]
    state = os.path.join(os.environ['XDG_RUNTIME_DIR'], 'brave-tz')
    while True:
        p = subprocess.Popen(['obscura', 'status', '--follow', '--json'],
                             stdout=subprocess.PIPE,
                             stderr=subprocess.DEVNULL, text=True)
        for status in statuses(p.stdout):
            tz = zone(status, home, exit_zone)
            if tz:
                apply(tz, home, state)
        p.wait()
        active = subprocess.run(
            ['systemctl', 'show', '-P', 'ActiveState', 'obscura.service'],
            capture_output=True, text=True).stdout.strip()
        if active in ('inactive', 'failed'):
            apply(home, home, state)
        time.sleep(5)


if __name__ == '__main__':
    main()
