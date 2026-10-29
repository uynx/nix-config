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


def profiles(last_active):
    names = {'Default': 'Personal', 'Profile 1': 'School'}
    return [names[p] for p in last_active if p in names] or ['Personal']


# Chromium rewrites its argv into one string and blanks its environ.
def brave():
    for pid in filter(str.isdigit, os.listdir('/proc')):
        try:
            with open(f'/proc/{pid}/cmdline', 'rb') as f:
                cmd = f.read().decode().replace('\0', ' ')
        except OSError:
            continue
        if ('/brave-origin/brave ' in cmd and '--type=' not in cmd
                and f'--user-data-dir={DATA} ' in cmd):
            return int(pid)
    return None


def apply(tz, home, state):
    try:
        with open(state) as f:
            old = f.read()
    except FileNotFoundError:
        old = home
    with open(state + '.tmp', 'w') as f:
        f.write(tz)
    os.replace(state + '.tmp', state)
    pid = brave()
    if pid is None or old == tz:
        return
    os.kill(pid, signal.SIGTERM)
    for _ in range(150):
        if not os.path.exists(f'/proc/{pid}'):
            break
        time.sleep(0.2)
    else:
        return
    with open(os.path.join(DATA, 'Local State')) as f:
        last = json.load(f)['profile'].get('last_active_profiles', [])
    for name in profiles(last):
        subprocess.run(['systemd-run', '--user', '--collect', '--quiet', '--',
                        'brave-activation', name, '--restore-last-session'])
        # A profile sent before startup settles opens blank, not restored.
        for _ in range(75):
            if brave():
                break
            time.sleep(0.2)
        time.sleep(5)


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
        active = subprocess.run(
            ['systemctl', 'show', '-P', 'ActiveState', 'obscura.service'],
            capture_output=True, text=True).stdout.strip()
        if active in ('inactive', 'failed'):
            apply(home, home, state)
        elif active == 'active':
            p = subprocess.Popen(
                ['obscura', 'status', '--follow', '--json'],
                stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
            for status in statuses(p.stdout):
                tz = zone(status, home, exit_zone)
                if tz:
                    apply(tz, home, state)
            p.wait()
        time.sleep(5)


if __name__ == '__main__':
    main()
