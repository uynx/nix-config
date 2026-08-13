{
  flake.homeModules.steamAsahi =
    {
      pkgs,
      lib,
      inputs,
      config,
      ...
    }:

    let
      N = "${lib.getExe pkgs.niri}";
      J = "${lib.getExe pkgs.jq}";

      # The container mounts this as the guest's $HOME, so every path the guest
      # and the host both touch hangs off it. `home.file` keys need the relative
      # form, the scripts need the absolute one.
      guestRel = ".local/share/steam-asahi/home";
      steamRel = "${guestRel}/.local/share/Steam";
      guest = "${config.home.homeDirectory}/${guestRel}";
      steam = "${config.home.homeDirectory}/${steamRel}";

      # niri calls Hyprland's `class` `app_id` and its `address` `id`, and
      # returns outputs as an object keyed by name rather than a list.
      shellHelpers = ''
        window_id() {
          ${N} msg -j windows 2>/dev/null | ${J} -r --arg app "$1" \
            '[.[] | select(((.app_id // "") | ascii_downcase) == $app) | .id][0] // empty' \
            2>/dev/null || true
        }

        any_steam_window() {
          ${N} msg -j windows 2>/dev/null | ${J} -e '
            any(.[]; ((.app_id // "") | ascii_downcase) as $c
                     | $c == "steam" or $c == "cs2" or ($c | test("^steam_app_[0-9]+$")))
          ' >/dev/null 2>&1
        }

        # niri opens windows on the focused output, so this cannot disagree
        # with where the window ends up — unlike naming a connector.
        target_output() {
          ${N} msg -j focused-output 2>/dev/null
        }

        # Two container variants, selected by STEAM_VARIANT. Both mount the same
        # guest home, so the Steam library and every prefix are shared and only
        # one may run at a time. `arch` is the experiment that can reach a 7.1
        # kernel; `fedora` stays the default until that is proven.
        steam_variant() {
          case "''${STEAM_VARIANT:-fedora}" in
            fedora)
              CONTAINER=steam-asahi
              IMAGE=localhost/steam-asahi:44
              CFILE=Containerfile
              INI=distrobox.ini
              ;;
            arch)
              CONTAINER=steam-asahi-arch
              IMAGE=localhost/steam-asahi-arch:1
              CFILE=Containerfile.arch
              INI=distrobox-arch.ini
              ;;
            *)
              printf 'unknown STEAM_VARIANT: %s\n' "''${STEAM_VARIANT:-}" >&2
              return 1
              ;;
          esac
        }
      '';
      x86-pkgs = import inputs.nixpkgs {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };
      x86-libgcc = x86-pkgs.stdenv.cc.cc.lib;
      steam-asahi-doctor = pkgs.writeShellScriptBin "steam-asahi-doctor" ''
        set -eu
        ${shellHelpers}
        steam_variant

        SOURCE=${config.home.homeDirectory}/nixos-config/steam-asahi

        # The NEVRA audit below is dnf-shaped and Arch has no equivalent, so
        # that variant gets the environment checks and nothing more.
        if [ "''${STEAM_VARIANT:-fedora}" = arch ]; then
          [ "$(${pkgs.glibc.bin}/bin/getconf PAGESIZE)" = 16384 ]
          [ -r /dev/kvm ] && [ -w /dev/kvm ]
          ${pkgs.docker}/bin/docker image inspect "$IMAGE" >/dev/null
          ${pkgs.docker}/bin/docker container inspect "$CONTAINER" >/dev/null
          printf '%-46s %s\n' "$CONTAINER" "ok (no package audit on arch)"
          exit 0
        fi

        [ "$(${pkgs.glibc.bin}/bin/getconf PAGESIZE)" = 16384 ]
        [ -r /dev/kvm ] && [ -w /dev/kvm ]
        ${pkgs.docker}/bin/docker image inspect "$IMAGE" >/dev/null
        ${pkgs.docker}/bin/docker container inspect "$CONTAINER" >/dev/null

        # Read out of the Containerfile rather than restated: a second copy of
        # the NEVRA list is one more thing to edit on every Fedora bump. Stops
        # at the first `dnf clean all`, so the box64 build deps removed in the
        # next layer never enter the list.
        ${pkgs.gawk}/bin/awk '
          /dnf install -y/ { f = 1 }
          f && /fc44/ { gsub(/['"'"' \\&]/, ""); print }
          /dnf clean all/ { exit }
        ' "$SOURCE/Containerfile" \
          | ${pkgs.findutils}/bin/xargs \
            ${pkgs.distrobox}/bin/distrobox enter "$CONTAINER" -- rpm -q >/dev/null
        ${pkgs.distrobox}/bin/distrobox enter "$CONTAINER" -- \
          test -e /usr/lib64/dri/asahi_dri.so
        ${pkgs.distrobox}/bin/distrobox enter "$CONTAINER" -- \
          test -e /usr/lib64/libvulkan_asahi.so
        ${pkgs.distrobox}/bin/distrobox enter "$CONTAINER" -- \
          test -x /opt/steam-arm64/steamrtarm64/steam
        ${pkgs.distrobox}/bin/distrobox enter "$CONTAINER" -- \
          test -x /usr/local/bin/box64
        printf '%s\n' "Steam Asahi container checks passed."
      '';

      # Rewrites the ordinary pins, holds the graphics/emulation ones. The two
      # dnf calls are per-list, not per-package: an exact-NEVRA query drops
      # pins that aged off the mirrors, which is the failure that stops the
      # image building at all and is invisible to steam-asahi-doctor.
      update-steam-asahi-pins = pkgs.writeShellScriptBin "update-steam-asahi-pins" ''
        set -eu

        FILE=${config.home.homeDirectory}/nixos-config/steam-asahi/Containerfile
        ENTER="${pkgs.distrobox}/bin/distrobox enter --no-workdir steam-asahi --"

        if ! ${pkgs.docker}/bin/docker container inspect steam-asahi >/dev/null 2>&1; then
          printf '%-46s %s\n' steam-asahi "no container, skipped"
          exit 0
        fi

        PINS=$(
          ${pkgs.gawk}/bin/awk '
            /dnf install -y/ { f = 1 }
            f && /fc44/ {
              line = $0
              gsub(/['"'"' \\&]/, "", line)
              if (!seen[line]++) print line
            }
            /dnf clean all/ { f = 0 }
          ' "$FILE"
        )

        # Unquoted on purpose: the NEVRA list is the argument vector, and no
        # NEVRA contains whitespace.
        # shellcheck disable=SC2086
        # %{version}-%{release}, not %{evr}: evr prefixes the epoch that the
        # pins omit, and NetworkManager (epoch 1) then never matches itself.
        # --arch keeps --latest-limit off the .src RPMs, which sort newest.
        # The format stays inline and quoted. Held in a variable it word-splits
        # on its own space, and dnf reads half the format as a package name.
        HAVE=$($ENTER dnf -q repoquery --available --arch aarch64,noarch \
          --qf '%{name} %{name}-%{version}-%{release}.%{arch}\n' $PINS 2>/dev/null || true)
        NAMES=$(printf '%s\n' "$HAVE" | ${pkgs.gawk}/bin/awk '{ print $1 }' | ${pkgs.coreutils}/bin/sort -u)
        # shellcheck disable=SC2086
        LATEST=$($ENTER dnf -q repoquery --available --arch aarch64,noarch --latest-limit 1 \
          --qf '%{name} %{name}-%{version}-%{release}.%{arch}\n' $NAMES 2>/dev/null || true)

        PLAN=$(printf '%s\n' "$PINS" | ${pkgs.gawk}/bin/awk -v have="$HAVE" -v latest="$LATEST" '
          BEGIN {
            n = split(have, h, "\n")
            for (i = 1; i <= n; i++) { split(h[i], a, " "); if (a[2] != "") name[a[2]] = a[1] }
            n = split(latest, l, "\n")
            for (i = 1; i <= n; i++) { split(l[i], a, " "); if (a[1] != "") newest[a[1]] = a[2] }
          }
          $0 == "" { next }
          !($0 in name) { print "GONE", $0, "-"; next }
          {
            new = newest[name[$0]]
            # Graphics and emulation are a matched set against the pinned host
            # kernel — moving them unattended is what killed every game on
            # 7.1.5. They always print, with or without an update, because
            # their standing versions are the thing worth watching.
            if (name[$0] ~ /^(virglrenderer|muvm|libkrun|mesa-|fex-|asahi-|steam|vulkan-loader)/) {
              if (new == "" || new == $0) print "HOLD", $0, "-"
              else print "HOLDNEW", $0, new
              next
            }
            if (new == "" || new == $0) next
            print "BUMP", $0, new
          }
        ')

        printf 'steam-asahi pins\n'

        TMP=$(${pkgs.coreutils}/bin/mktemp)
        ${pkgs.coreutils}/bin/cp "$FILE" "$TMP"
        printf '%s\n' "$PLAN" | while read -r kind old new; do
          case $kind in
            BUMP)
              ${pkgs.gnused}/bin/sed -i "s|$old|$new|" "$TMP"
              printf '  %-46s -> %s\n' "$old" "$new"
              ;;
            HOLD) printf '  %-46s %s\n' "$old" "(up to date, held)" ;;
            HOLDNEW) printf '  %-46s -> %s (held, kernel-coupled)\n' "$old" "$new" ;;
            GONE) printf '  %-46s %s\n' "$old" "GONE from the repos, pin by hand" ;;
          esac
        done

        # Only rewrite when something actually moved, so an unchanged run
        # leaves the file's mtime and the container config hash alone.
        if printf '%s\n' "$PLAN" | ${pkgs.gnugrep}/bin/grep -q '^BUMP'; then
          # Written back through cat so the file keeps its own permissions.
          ${pkgs.coreutils}/bin/cat "$TMP" >"$FILE"
          printf '  %s\n' "updated — next game launch rebuilds the container"
        else
          printf '  %s\n' "nothing to update"
        fi
        ${pkgs.coreutils}/bin/rm -f "$TMP"
      '';

      steam-asahi-bootstrap = pkgs.writeShellScriptBin "steam-asahi-bootstrap" ''
        set -eu

        ${shellHelpers}
        steam_variant

        SOURCE=${config.home.homeDirectory}/nixos-config/steam-asahi
        LABEL=io.uynx.steam-asahi.config

        if [ ! -f "$SOURCE/$CFILE" ] \
          || [ ! -f "$SOURCE/$INI" ] \
          || [ ! -f "$SOURCE/steam-guest-tune" ]; then
          ${pkgs.libnotify}/bin/notify-send \
            "Steam setup unavailable" \
            "Missing the versioned steam-asahi container files."
          exit 1
        fi

        CONFIG_HASH=$(
          ${pkgs.coreutils}/bin/sha256sum \
            "$SOURCE/$CFILE" "$SOURCE/$INI" \
            "$SOURCE/steam-guest-tune" \
            | ${pkgs.coreutils}/bin/sha256sum \
            | ${pkgs.coreutils}/bin/cut -d' ' -f1
        )
        IMAGE_HASH=$(
          ${pkgs.docker}/bin/docker image inspect \
            --format "{{ index .Config.Labels \"$LABEL\" }}" \
            "$IMAGE" 2>/dev/null || true
        )
        REPLACE=0

        if [ "$IMAGE_HASH" != "$CONFIG_HASH" ]; then
          ${pkgs.docker}/bin/docker build \
            --label "$LABEL=$CONFIG_HASH" \
            --tag "$IMAGE" \
            --file "$SOURCE/$CFILE" \
            "$SOURCE"
          REPLACE=1
        fi

        IMAGE_ID=$(
          ${pkgs.docker}/bin/docker image inspect \
            --format '{{.Id}}' "$IMAGE"
        )
        if ! ${pkgs.docker}/bin/docker container inspect "$CONTAINER" >/dev/null 2>&1; then
          ${pkgs.distrobox}/bin/distrobox assemble create \
            --file "$SOURCE/$INI"
          REPLACE=0
        else
          CONTAINER_IMAGE_ID=$(
            ${pkgs.docker}/bin/docker container inspect \
              --format '{{.Image}}' "$CONTAINER"
          )
        fi
        if [ "$REPLACE" = 1 ] || \
           { [ -n "''${CONTAINER_IMAGE_ID:-}" ] && [ "$CONTAINER_IMAGE_ID" != "$IMAGE_ID" ]; }; then
          ${pkgs.distrobox}/bin/distrobox assemble create \
            --replace \
            --file "$SOURCE/$INI"
        fi

        # No rpm -q here: the image carries the Containerfile's hash as a label
        # and is rebuilt whenever that changes, and dnf installs those exact
        # NEVRAs or fails the build. `steam-asahi-doctor` checks them.
        ${pkgs.distrobox}/bin/distrobox enter "$CONTAINER" -- \
          test -x /opt/steam-arm64/steamrtarm64/steam
      '';

      # Stopping the container is the one reliable process boundary: it cannot
      # leave a second Steam client, FEX process, or Venus VM behind.
      steam-asahi-stop = pkgs.writeShellScriptBin "steam-asahi-stop" ''
        set -eu
        ${shellHelpers}
        steam_variant

        RUNTIME_DIR=''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
        if [ "$(${pkgs.docker}/bin/docker container inspect \
          --format '{{.State.Running}}' "$CONTAINER" 2>/dev/null || true)" = true ]; then
          ${pkgs.docker}/bin/docker container stop --time 5 "$CONTAINER" >/dev/null
        fi

        # Watchers live outside the container; their stale locks would block the
        # next launch.
        for LOCK in "$RUNTIME_DIR"/steam-asahi-launch-*; do
          [ -d "$LOCK" ] || continue
          WATCH_PID=$(cat "$LOCK/pid" 2>/dev/null || true)
          if [ -n "$WATCH_PID" ] && [ "$WATCH_PID" != "$PPID" ]; then
            WATCH_ARGS=$(${pkgs.procps}/bin/ps -p "$WATCH_PID" -o args= 2>/dev/null || true)
            case "$WATCH_ARGS" in
              *steam-game-watch*"$LOCK"*) kill "$WATCH_PID" 2>/dev/null || true ;;
            esac
          fi
          rm -rf "$LOCK"
        done

        # Runtime-only sockets; an interrupted muvm session leaves them behind and
        # blocks the next clean launch.
        rm -rf \
          "$RUNTIME_DIR/krun" \
          "$RUNTIME_DIR/muvm.lock"
        # steam.pipe outlives the client that made it, and `steam-launch` reads
        # its mere existence as "client is live" — so every later launch took the
        # remote path and skipped `steam-asahi-run`, losing the FEX RootFS mount,
        # --vram and the max_map_count tune.
        rm -f \
          ${guest}/.cache/steam-asahi/open-url.pipe \
          ${guest}/.steam/steam.pipe
      '';

      # Distrobox's xdg-open forwarding cannot cross muvm's VM boundary, so web
      # URLs go out through a FIFO in the shared Steam home instead.
      steam-guest-open = pkgs.writeShellScript "steam-guest-open" ''
        set -eu

        FIFO=${guest}/.cache/steam-asahi/open-url.pipe
        [ "$#" = 1 ] || exit 2
        case "$1" in
          http://* | https://*) ;;
          *) exit 2 ;;
        esac
        [ -p "$FIFO" ] || exit 1
        printf '%s\n' "$1" >"$FIFO"
      '';

      steam-url-bridge = pkgs.writeShellScriptBin "steam-url-bridge" ''
        set -eu

        FIFO=$1
        exec 3<>"$FIFO"
        while IFS= read -r URL <&3; do
          case "$URL" in
            http://* | https://*)
              ${pkgs.xdg-utils}/bin/xdg-open "$URL" >/dev/null 2>&1 || true
              ;;
          esac
        done <"$FIFO"
      '';

      # Denuvo in Hogwarts' 2023 build rewrites its own code inline and leans on
      # 16-byte atomics. On FEX's defaults that means a permanent fault loop in
      # the anti-tamper VM, then a torn compare-exchange and a corrupted
      # pointer. `full` is lowercase on purpose — the enum is case-sensitive and
      # an unrecognised value is ignored silently, which looks identical to the
      # setting not helping.
      fex-hogwarts-config = pkgs.writeText "fex-hogwarts.json" (builtins.toJSON {
        Config = {
          SMCChecks = "full";
          StrictInProcessSplitLocks = true;
          Multiblock = false;
        };
        ThunksDB = { };
      });

      # Two Hogwarts installs live side by side: the current build, and the
      # 8 Mar 2023 one its skeletal-mesh mod set requires. Swapping renames
      # directories, so the *names* stop describing their contents after the
      # first swap — that inversion has already cost one debugging session.
      # A marker file inside each directory is the authority instead.
      hogwarts-build = pkgs.writeShellScriptBin "hogwarts-build" ''
        set -eu
        C=${guest}/.local/share/Steam/steamapps/common
        LIVE="$C/Hogwarts Legacy"
        PARKED="$C/Hogwarts Legacy.parked"
        id_of() { cat "$1/.hl-build" 2>/dev/null || echo unknown; }

        case "''${1-status}" in
          status)
            printf 'live:   %s\nparked: %s\n' "$(id_of "$LIVE")" "$(id_of "$PARKED")"
            exit 0
            ;;
          2023 | 2026) want=$1 ;;
          *) echo "usage: hogwarts-build [2023|2026|status]" >&2; exit 2 ;;
        esac

        [ -d "$LIVE" ] && [ -d "$PARKED" ] || {
          echo "need both '$LIVE' and '$PARKED'" >&2; exit 1; }
        for d in "$LIVE" "$PARKED"; do
          [ -f "$d/.hl-build" ] || {
            echo "missing $d/.hl-build — label each install once, by hand" >&2; exit 1; }
        done

        if [ "$(id_of "$LIVE")" = "$want" ]; then
          echo "already on $want"
          exit 0
        fi
        mv "$LIVE" "$C/.hl-swap"
        mv "$PARKED" "$LIVE"
        mv "$C/.hl-swap" "$PARKED"
        printf 'live:   %s\nparked: %s\n' "$(id_of "$LIVE")" "$(id_of "$PARKED")"
      '';

      steam-compat-config = pkgs.writers.writePython3Bin "steam-compat-config" { } ''
        import re
        import sys
        from pathlib import Path

        # Split to stay under flake8's E501, which writePython3Bin enforces.
        config = Path(
            "${guest}/"
            ".local/share/Steam/config/config.vdf"
        )
        app_id, tool = sys.argv[1:3]
        if config.is_file():
            text = config.read_text()
        else:
            config.parent.mkdir(parents=True, exist_ok=True)
            text = (
                '"InstallConfigStore"\n{\n'
                '\t"Software"\n\t{\n'
                '\t\t"Valve"\n\t\t{\n'
                '\t\t\t"Steam"\n\t\t\t{\n'
                '\t\t\t}\n\t\t}\n\t}\n}\n'
            )


        def block_for_key(source, key, low=0, high=None):
            if high is None:
                high = len(source)
            match = re.search(r'"' + re.escape(key) + r'"\s*\{', source[low:high])
            if not match:
                return None
            opening = low + match.end() - 1
            depth = 0
            quoted = False
            escaped = False
            for pos in range(opening, high):
                char = source[pos]
                if quoted:
                    if escaped:
                        escaped = False
                    elif char == "\\":
                        escaped = True
                    elif char == '"':
                        quoted = False
                elif char == '"':
                    quoted = True
                elif char == "{":
                    depth += 1
                elif char == "}":
                    depth -= 1
                    if depth == 0:
                        return opening, pos
            return None


        region = (0, len(text))
        for key in ("InstallConfigStore", "Software", "Valve", "Steam"):
            found = block_for_key(text, key, region[0], region[1])
            if found is None:
                raise SystemExit(0)
            region = found

        mapping = block_for_key(text, "CompatToolMapping", region[0], region[1])
        entry = (
            f'\n\t\t\t\t\t"{app_id}"\n'
            "\t\t\t\t\t{\n"
            f'\t\t\t\t\t\t"name"\t\t"{tool}"\n'
            '\t\t\t\t\t\t"config"\t\t""\n'
            '\t\t\t\t\t\t"priority"\t\t"250"\n'
            "\t\t\t\t\t}\n\t\t\t\t"
        )
        if mapping is None:
            insertion = (
                '\n\t\t\t\t"CompatToolMapping"\n'
                "\t\t\t\t{" + entry + "}\n\t\t\t"
            )
            text = text[:region[1]] + insertion + text[region[1]:]
        else:
            app = block_for_key(text, app_id, mapping[0], mapping[1])
            if app is None:
                text = text[:mapping[0] + 1] + entry + text[mapping[0] + 1:]
            else:
                body = text[app[0]:app[1]]
                updated, count = re.subn(
                    r'("name"\s*")[^"]*(")',
                    rf'\g<1>{tool}\g<2>',
                    body,
                    count=1,
                )
                if count == 0:
                    updated = body[:1] + f'\n\t"name"\t\t"{tool}"' + body[1:]
                text = text[:app[0]] + updated + text[app[1]:]

        temporary = config.with_suffix(".vdf.tmp")
        if not config.is_file() or config.read_text() != text:
            temporary.write_text(text)
            temporary.replace(config)
      '';

      steam-asahi-remote = pkgs.writeShellScriptBin "steam-asahi-remote" ''
        set -eu
        ${shellHelpers}
        steam_variant

        TARGET=$1
        case "$TARGET" in
          ui)
            URL=steam://open/main
            ;;
          *[!0-9]*|"")
            exit 2
            ;;
          *)
            URL=steam://rungameid/$TARGET
            ;;
        esac

        STEAM_HOME=${guest}/.steam
        STEAM_BIN="$STEAM_HOME/root/steamrtarm64/steam"
        [ -p "$STEAM_HOME/steam.pipe" ] && [ -x "$STEAM_BIN" ]

        if [ "$TARGET" = 730 ]; then
          exec ${pkgs.distrobox}/bin/distrobox enter --no-workdir "$CONTAINER" -- \
            /usr/bin/muvm -i -- "$STEAM_BIN" -applaunch "$TARGET" \
              -condebug +r_csgo_player_occlusion_query 0
        fi

        exec ${pkgs.distrobox}/bin/distrobox enter --no-workdir "$CONTAINER" -- \
          /usr/bin/muvm -i -- "$STEAM_BIN" "$URL"
      '';

      steam-asahi-run = pkgs.writeShellScriptBin "steam-asahi-run" ''
        set -eu
        ${shellHelpers}
        steam_variant

        APP_ID=''${1:-}
        ${steam-asahi-bootstrap}/bin/steam-asahi-bootstrap

        # Steam's FEX compat tool expects the OS to supply a combined FEX+Mesa
        # x86 rootfs here, and it has to be the Arch image FEX publishes — the
        # tool's own source calls it an "arch linux install". Fedora's rootfs
        # shares sonames with the aarch64 container, so pressure-vessel hands
        # host binaries 32-bit libraries and every Proton game dies before
        # Proton starts. The Arch image carries its own graphics_provider.json;
        # do not hand-write one. Container side, not the guest: muvm does not
        # propagate a loop mount made inside it.
        ROOTFS=/home/uynx/.local/share/steam-asahi/ArchLinux.ero
        if [ ! -e "$ROOTFS" ]; then
          ${pkgs.curl}/bin/curl -fsSL --connect-timeout 10 -o "$ROOTFS.part" \
            https://rootfs.fex-emu.gg/ArchLinux/2026-08-11/ArchLinux.ero
          echo "b035dcfe31a3d8e7ee497f2809caa11bf3a85bc68d707c7621d7433839d19ff2  $ROOTFS.part" \
            | ${pkgs.coreutils}/bin/sha256sum -c -
          ${pkgs.coreutils}/bin/mv "$ROOTFS.part" "$ROOTFS"
        fi
        ${pkgs.distrobox}/bin/distrobox enter --no-workdir "$CONTAINER" -- sudo sh -c \
          'grep -qs " /usr/share/guestos/fex-mesa " /proc/mounts || {
             mkdir -p /usr/share/guestos/fex-mesa
             mount -o loop,ro /home/uynx/.local/share/steam-asahi/ArchLinux.ero \
               /usr/share/guestos/fex-mesa
           }'

        ${steam-compat-config}/bin/steam-compat-config 32440 proton_10
        # Native aarch64 Wine, with FEX translating only the game's own x86.
        # Both of these stalled under the old stack and run under this one.
        ${steam-compat-config}/bin/steam-compat-config 674940 proton-experimental-arm64
        ${steam-compat-config}/bin/steam-compat-config 3540 proton-experimental-arm64
        # Hogwarts is pinned to the 2023 build, which spins forever in ntdll
        # under Proton 10. Proton 8 is the closest release to that build that
        # still starts it. Do not "upgrade" this to match the other games.
        ${steam-compat-config}/bin/steam-compat-config 990080 proton_8

        # The 2023 build refuses to start unless the VC++ redistributable is
        # registered, though Wine's builtin runtime DLLs serve it fine. Steam
        # rebuilds this prefix whenever the Proton version changes and takes
        # the keys with it, so re-assert them on every launch.
        HL_REG=${guest}/.local/share/Steam/steamapps/compatdata/990080/pfx/system.reg
        if [ -f "$HL_REG" ] && ! ${pkgs.gnugrep}/bin/grep -q 'VC\\\\Runtimes' "$HL_REG"; then
          printf '\n[Software\\\\Microsoft\\\\VisualStudio\\\\14.0\\\\VC\\\\Runtimes\\\\x64] %s\n"Installed"=dword:00000001\n"Major"=dword:0000000e\n"Minor"=dword:00000026\n"Bld"=dword:0000816a\n"RBld"=dword:00000000\n"Version"="14.38.33130.0"\n' \
            "$(${pkgs.coreutils}/bin/date +%s)" >>"$HL_REG"
        fi

        STEAM_ROOT=${steam}
        STEAM_HOME=${guest}/.steam
        STEAM_BIN="$STEAM_ROOT/steamrtarm64/steam"
        GUEST_BIN=${guest}/.local/bin
        URL_FIFO=${guest}/.cache/steam-asahi/open-url.pipe

        mkdir -p "$GUEST_BIN" "$(dirname "$URL_FIFO")"
        install -m 0755 ${steam-guest-open} "$GUEST_BIN/xdg-open"
        rm -f "$URL_FIFO"
        mkfifo -m 0600 "$URL_FIFO"
        ${steam-url-bridge}/bin/steam-url-bridge "$URL_FIFO" &
        URL_BRIDGE_PID=$!
        cleanup_url_bridge() {
          kill "$URL_BRIDGE_PID" 2>/dev/null || true
          wait "$URL_BRIDGE_PID" 2>/dev/null || true
          rm -f "$URL_FIFO"
        }
        trap cleanup_url_bridge EXIT INT TERM HUP

        if [ ! -x "$STEAM_BIN" ]; then
          mkdir -p "$STEAM_ROOT"
          cp -a /opt/steam-arm64/steamrtarm64 "$STEAM_ROOT/"
        fi
        mkdir -p "$STEAM_ROOT/package" "$STEAM_HOME"
        printf '%s\n' "''${STEAM_CLIENT_BRANCH-publicbeta}" >"$STEAM_ROOT/package/beta"
        ln -sfn "$STEAM_ROOT" "$STEAM_HOME/root"
        ln -sfn "$STEAM_ROOT/linuxarm64" "$STEAM_HOME/sdkarm64"
        chmod -R u+rwX "$STEAM_ROOT/steamrtarm64"

        if [ -n "$APP_ID" ]; then
          case "$APP_ID" in
            *[!0-9]*) exit 2 ;;
          esac
        fi

        # Hogwarts is pinned to the 2023 build its mods need; an online client
        # repatches it to current on every -applaunch. Only ever force offline,
        # never force online: an online client also installs Valve's FEX compat
        # tool, which has no RootFS here and breaks every Proton game.
        LOGINUSERS=${steam}/config/loginusers.vdf
        if [ "$APP_ID" = 990080 ] && [ -f "$LOGINUSERS" ]; then
          ${pkgs.gnused}/bin/sed -i \
            -e 's/\("WantsOfflineMode"[[:space:]]*"\)[01]/\11/' \
            -e 's/\("SkipOfflineModeWarning"[[:space:]]*"\)[01]/\11/' \
            "$LOGINUSERS"
        fi

        set -- /usr/bin/muvm \
          -e "BROWSER=$GUEST_BIN/xdg-open" \
          --gpu-mode=venus
        if [ "$APP_ID" = 990080 ]; then
          # Hogwarts otherwise grows Venus past this 16 GiB host's headroom.
          set -- "$@" --vram=2048
          # Per-game FEX tuning. Passed here rather than through Steam's launch
          # options, which live in localconfig.vdf and are rewritten by Steam.
          set -- "$@" -e "FEX_APP_CONFIG=${fex-hogwarts-config}"
        fi
        set -- "$@" --execute-pre=/usr/local/libexec/steam-guest-tune -- \
          "$STEAM_BIN"
        if [ "$APP_ID" = 730 ]; then
          set -- "$@" -silent -applaunch "$APP_ID" \
            -condebug +r_csgo_player_occlusion_query 0
        elif [ -n "$APP_ID" ]; then
          set -- "$@" -silent -applaunch "$APP_ID"
        fi

        STATUS=0
        ${pkgs.distrobox}/bin/distrobox enter --no-workdir "$CONTAINER" -- "$@" || STATUS=$?
        ${steam-asahi-stop}/bin/steam-asahi-stop
        exit "$STATUS"
      '';

      # Native ARM64 client: FEX's Steam UI hits a restart/focus loop. Windows
      # games still go through Proton and FEX inside the same Venus VM.
      steam-asahi = pkgs.writeShellScriptBin "steam-asahi" ''
        set -eu
        ${shellHelpers}
        steam_variant

        STEAM_ID=$(window_id steam)
        if [ -n "$STEAM_ID" ]; then
          exec ${N} msg action focus-window --id "$STEAM_ID"
        fi

        if [ "$(${pkgs.docker}/bin/docker container inspect \
          --format '{{.State.Running}}' "$CONTAINER" 2>/dev/null || true)" = true ] && \
           [ -p ${guest}/.steam/steam.pipe ]; then
          ${steam-asahi-remote}/bin/steam-asahi-remote ui || true
          for _ in $(${pkgs.coreutils}/bin/seq 1 50); do
            STEAM_ID=$(window_id steam)
            if [ -n "$STEAM_ID" ]; then
              exec ${N} msg action focus-window --id "$STEAM_ID"
            fi
            sleep 0.1
          done
          exit 0
        fi

        ${steam-asahi-stop}/bin/steam-asahi-stop
        exec ${steam-asahi-run}/bin/steam-asahi-run "$@"
      '';

      # Focuses the game window, then shuts the VM down once the last Steam
      # window is gone. Do not add fullscreening here: niri's IPC cannot report
      # whether a window already is, so a toggle is a coin flip. That lives in
      # the niri config's `window-rule { open-fullscreen true }`.
      steam-game-watch = pkgs.writeShellScriptBin "steam-game-watch" ''
        set -u
        ${shellHelpers}

        APP_ID=$1
        LOCK=$2
        if [ "$APP_ID" = 730 ]; then
          APP=cs2
        else
          APP=steam_app_$APP_ID
        fi
        cleanup() { rm -rf "$LOCK"; }
        trap cleanup EXIT
        printf '%s\n' "$$" >"$LOCK/pid"

        ID=
        for _ in $(${pkgs.coreutils}/bin/seq 1 600); do
          ID=$(window_id "$APP")
          [ -n "$ID" ] && break
          sleep 0.5
        done

        if [ -z "$ID" ]; then
          any_steam_window || ${steam-asahi-stop}/bin/steam-asahi-stop
          exit 0
        fi

        ${N} msg action focus-window --id "$ID" >/dev/null 2>&1 || true

        while [ -n "$(window_id "$APP")" ]; do
          sleep 0.5
        done
        sleep 1

        any_steam_window || ${steam-asahi-stop}/bin/steam-asahi-stop
      '';

      # Match Wine's virtual desktop and each game's own config to the target
      # monitor's exact size, then hand off to the client.
      steam-launch = pkgs.writeShellScriptBin "steam-launch" ''
        set -eu
        ${shellHelpers}
        steam_variant

        APP_ID=$1
        case "$APP_ID" in
          *[!0-9]*|"") exit 2 ;;
        esac

        if [ "$APP_ID" = 730 ]; then
          APP=cs2
        else
          APP=steam_app_$APP_ID
        fi
        GAME_ID=$(window_id "$APP")
        if [ -n "$GAME_ID" ]; then
          exec ${N} msg action focus-window --id "$GAME_ID"
        fi

        LOCK="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/steam-asahi-launch-$APP_ID"
        if ! mkdir "$LOCK" 2>/dev/null; then
          WATCH_PID=$(cat "$LOCK/pid" 2>/dev/null || true)
          if [ -n "$WATCH_PID" ] && kill -0 "$WATCH_PID" 2>/dev/null; then
            ${pkgs.libnotify}/bin/notify-send \
              "Steam game is already launching" \
              "Waiting for app $APP_ID."
            exit 0
          fi
          rm -rf "$LOCK"
          mkdir "$LOCK"
        fi
        WATCH_STARTED=0
        cleanup_launch() {
          [ "$WATCH_STARTED" = 1 ] || rm -rf "$LOCK"
        }
        trap cleanup_launch EXIT

        case "$APP_ID" in
          32440)
            ${steam-compat-config}/bin/steam-compat-config "$APP_ID" proton_10
            ;;
          990080)
            ${steam-compat-config}/bin/steam-compat-config "$APP_ID" proton_8
            ;;
          674940|3540)
            ${steam-compat-config}/bin/steam-compat-config "$APP_ID" proton-experimental-arm64
            ;;
        esac

        # Mode, not `logical`: these are X11 clients and xwayland-satellite does
        # not scale, so they see raw pixels (3024x1890, not 1512x945). Hyprland's
        # XWayland did scale, which is why logical was right before and is not now.
        OUTPUT=$(target_output)
        if ! RESOLUTION=$(printf '%s' "$OUTPUT" | ${J} -er '
          .modes[.current_mode] | select(.width > 0 and .height > 0)
          | "\(.width)x\(.height)"
        ' 2>/dev/null); then
          ${pkgs.libnotify}/bin/notify-send \
            "Steam game not launched" \
            "Could not read the target monitor resolution from niri."
          exit 1
        fi
        WIDTH=''${RESOLUTION%x*}
        HEIGHT=''${RESOLUTION#*x}

        if [ "$APP_ID" = 730 ]; then
          CS2_VIDEO=${steam}/userdata/483670283/730/local/cfg/cs2_video.txt
          # CS2 indexes monitors in X's enumeration order, i.e. left to right.
          CS2_MONITOR=$(${N} msg -j outputs 2>/dev/null | ${J} -r \
            --arg name "$(printf '%s' "$OUTPUT" | ${J} -r '.name')" '
              [to_entries[] | select(.value.logical) | {name: .key, x: .value.logical.x}]
              | sort_by(.x) | map(.name) | index($name) // 0
            ' 2>/dev/null || echo 0)
          # niri reports refresh rate in millihertz; Hyprland reported Hz.
          CS2_REFRESH=$(printf '%s' "$OUTPUT" | ${J} -r '
            (.modes[.current_mode].refresh_rate / 1000) | round
          ' 2>/dev/null || echo 60)
          if [ -f "$CS2_VIDEO" ]; then
            sed -i -E \
              -e "s/(\"setting.defaultres\"[[:space:]]+\")[0-9]+/\1$WIDTH/" \
              -e "s/(\"setting.defaultresheight\"[[:space:]]+\")[0-9]+/\1$HEIGHT/" \
              -e "s/(\"setting.refreshrate_numerator\"[[:space:]]+\")[0-9]+/\1$((CS2_REFRESH * 1000))/" \
              -e 's/("setting.refreshrate_denominator"[[:space:]]+")[0-9]+/\11000/' \
              -e "s/(\"setting.monitor_index\"[[:space:]]+\")[0-9]+/\1$CS2_MONITOR/" \
              -e 's/("setting.aspectratiomode"[[:space:]]+")[0-9]+/\11/' \
              "$CS2_VIDEO"
          fi
        fi

        COMPAT="${steam}/steamapps/compatdata"
        PREFIX="$COMPAT/''${APP_ID}/pfx"
        REG_FILE="$PREFIX/user.reg"
        if [ "$APP_ID" = 3540 ] && [ -f "$REG_FILE" ]; then
          STAMP=$(date +%s)
          # An older version of this helper let printf eat the registry
          # backslashes; drop those malformed sections before writing real keys.
          sed -i -E \
            -e '/^\[SoftwareWineExplorer\]/,/^$/d' \
            -e '/^\[SoftwareWineExplorerDesktops\]/,/^$/d' \
            "$REG_FILE"
          if ! grep -Fq '[Software\\Wine\\Explorer]' "$REG_FILE"; then
            printf '\n%s %s\n#time=%s\n"Desktop"="Default"\n' \
              '[Software\\Wine\\Explorer]' "$STAMP" "$STAMP" >>"$REG_FILE"
          fi
          if grep -Fq '[Software\\Wine\\Explorer\\Desktops]' "$REG_FILE"; then
            sed -i -E \
              -e "s/\"Default\"=\"[0-9]+x[0-9]+\"/\"Default\"=\"''$RESOLUTION\"/g" \
              -e "s/\"Peggle\"=\"[0-9]+x[0-9]+\"/\"Peggle\"=\"''$RESOLUTION\"/g" \
              "$REG_FILE"
          else
            printf '\n%s %s\n#time=%s\n"Default"="%s"\n"Peggle"="%s"\n' \
              '[Software\\Wine\\Explorer\\Desktops]' \
              "$STAMP" "$STAMP" "$RESOLUTION" "$RESOLUTION" >>"$REG_FILE"
          fi
          sed -i -E \
            -e 's/"ScreenMode"=dword:[0-9a-fA-F]+/"ScreenMode"=dword:00000001/' \
            -e 's/"CustomCursors"=dword:[0-9a-fA-F]+/"CustomCursors"=dword:00000000/' \
            "$REG_FILE"
        fi

        # Three keys, none of which the game can be trusted to set itself. The
        # Screenmanager pair is the window, and follows the monitor like every
        # other game here; this stack's display query hands Unity a zero width
        # it then persists, and `Resolution` 0 ("follow the desktop") makes it
        # ask that same broken query and fall back to 640x480. Fullscreen must
        # stay 0: Unity locks the cursor in fullscreen and xwayland-satellite
        # does not honour the constraint, which freezes the pointer outright.
        if [ "$APP_ID" = 674940 ] && [ -f "$REG_FILE" ]; then
          sed -i -E \
            -e "s/(\"Screenmanager Resolution Width_h182942802\"=dword:)[0-9a-fA-F]+/\1$(printf '%08x' "$WIDTH")/" \
            -e "s/(\"Screenmanager Resolution Height_h2627697771\"=dword:)[0-9a-fA-F]+/\1$(printf '%08x' "$HEIGHT")/" \
            -e 's/"Screenmanager Is Fullscreen mode_h3981298716"=dword:[0-9a-fA-F]+/"Screenmanager Is Fullscreen mode_h3981298716"=dword:00000000/' \
            -e 's/"Resolution_h2981718891"=dword:[0-9a-fA-F]+/"Resolution_h2981718891"=dword:00000026/' \
            "$REG_FILE"
        fi

        PC_CONFIG=
        if [ "$APP_ID" = 32440 ]; then
          PC_CONFIG=$(find "$PREFIX/drive_c/users/steamuser/AppData/Local" \
            -type f -name pcconfig.txt -print -quit 2>/dev/null || true)
        fi
        if [ -n "$PC_CONFIG" ] && [ -f "$PC_CONFIG" ]; then
          chmod u+w "$PC_CONFIG"
          sed -i -E \
            -e "s/^ScreenWidth[[:space:]]+[0-9]+/ScreenWidth            ''$WIDTH/" \
            -e "s/^ScreenHeight[[:space:]]+[0-9]+/ScreenHeight           ''$HEIGHT/" \
            -e "s/^WindowWidth[[:space:]]+[0-9]+/WindowWidth            ''$WIDTH/" \
            -e "s/^WindowHeight[[:space:]]+[0-9]+/WindowHeight           ''$HEIGHT/" \
            -e "s/^WindowLeft[[:space:]]+[0-9]+/WindowLeft             0/" \
            -e "s/^WindowTop[[:space:]]+[0-9]+/WindowTop              0/" \
            -e "s/^Widescreen[[:space:]]+[0-9]+/Widescreen             1/" \
            "$PC_CONFIG"
          chmod u-w "$PC_CONFIG"
        fi

        ${pkgs.util-linux}/bin/setsid \
          ${steam-game-watch}/bin/steam-game-watch "$APP_ID" "$LOCK" \
          >/dev/null 2>&1 &
        WATCH_STARTED=1

        CONTAINER_RUNNING=$(${pkgs.docker}/bin/docker container inspect \
          --format '{{.State.Running}}' "$CONTAINER" 2>/dev/null || true)
        if [ "$CONTAINER_RUNNING" = true ]; then
          for _ in $(${pkgs.coreutils}/bin/seq 1 100); do
            [ -p ${guest}/.steam/steam.pipe ] && break
            sleep 0.1
          done
          if [ -p ${guest}/.steam/steam.pipe ]; then
            ${steam-asahi-remote}/bin/steam-asahi-remote "$APP_ID"
            exit 0
          fi

          if [ -n "$(window_id steam)" ]; then
            ${pkgs.libnotify}/bin/notify-send \
              "Steam game not launched" \
              "Steam is still starting; try again in a moment."
            exit 1
          fi
          ${steam-asahi-stop}/bin/steam-asahi-stop
        fi

        exec ${steam-asahi-run}/bin/steam-asahi-run "$APP_ID"
      '';

      steam-game-entries = pkgs.writeShellScriptBin "steam-game-entries" ''
        set -eu

        STEAM_ROOT=${steam}
        APPLICATIONS="''${XDG_DATA_HOME:-$HOME/.local/share}/applications"
        MANIFESTS=$(mktemp)
        GENERATED=$(mktemp -d)
        trap 'rm -f "$MANIFESTS"; rm -rf "$GENERATED"' EXIT

        {
          printf '%s\n' "$STEAM_ROOT"
          sed -n 's/.*"path"[[:space:]]*"\([^"]*\)".*/\1/p' \
            "$STEAM_ROOT/steamapps/libraryfolders.vdf" 2>/dev/null || true
        } | while IFS= read -r LIBRARY; do
          [ -d "$LIBRARY" ] || continue
          find "$LIBRARY/steamapps" -maxdepth 1 -type f \
            -name 'appmanifest_*.acf' -print
        done | sort -u >"$MANIFESTS"

        while IFS= read -r MANIFEST; do
          APP_ID=$(sed -n 's/.*"appid"[[:space:]]*"\([0-9]*\)".*/\1/p' "$MANIFEST" | head -n 1)
          NAME=$(sed -n 's/.*"name"[[:space:]]*"\([^"]*\)".*/\1/p' "$MANIFEST" | head -n 1)
          OWNER=$(sed -n 's/.*"LastOwner"[[:space:]]*"\([0-9]*\)".*/\1/p' "$MANIFEST" | head -n 1)
          [ -n "$APP_ID" ] && [ -n "$NAME" ] && [ "$OWNER" != 0 ] || continue
          case "$NAME" in
            Proton\ *|Steam\ Linux\ Runtime*|Steamworks\ Common\ Redistributables)
              continue
              ;;
          esac

          printf '%s\n' \
            '[Desktop Entry]' \
            'Type=Application' \
            "Name=$NAME" \
            'GenericName=Steam Game' \
            "Exec=${steam-launch}/bin/steam-launch $APP_ID" \
            'Icon=steam' \
            'Terminal=false' \
            'Categories=Game;' \
            "X-Steam-AppID=$APP_ID" \
            >"$GENERATED/steam-game-$APP_ID.desktop"
        done <"$MANIFESTS"

        mkdir -p "$APPLICATIONS"
        find "$APPLICATIONS" -maxdepth 1 -type f -name 'steam-game-*.desktop' -delete
        find "$GENERATED" -maxdepth 1 -type f -name '*.desktop' \
          -exec cp {} "$APPLICATIONS/" \;
      '';

      steam-menu = pkgs.writeShellScriptBin "steam-menu" ''
        ${steam-game-entries}/bin/steam-game-entries
        exec ${pkgs.noctalia-shell}/bin/noctalia-shell ipc call launcher toggle
      '';

      # Bound to Mod+W and Mod+Q. niri's close-window is wrong for Steam: closing
      # the XWayland window leaves Proton and the game running headless in the VM.
      close-active = pkgs.writeShellScriptBin "close-active" ''
        set -eu

        ACTIVE=$(${N} msg -j focused-window 2>/dev/null || echo '{}')
        APP=$(printf '%s' "$ACTIVE" | ${J} -r '.app_id // ""' 2>/dev/null || true)
        case "$APP" in
          steam|Steam|steam_app_[0-9]*|cs2)
            exec ${steam-asahi-stop}/bin/steam-asahi-stop
            ;;
          *)
            exec ${N} msg action close-window
            ;;
        esac
      '';
    in
    {
      home.packages = with pkgs; [
        steam-asahi
        steam-asahi-bootstrap
        steam-asahi-doctor
        steam-asahi-stop
        steam-game-entries
        steam-menu
        hogwarts-build
        update-steam-asahi-pins
        distrobox
        dive
        close-active
      ];

      # Reports only, so it cannot half-update a pin set and abort the relock.
      shellHooks.update = [ "update-steam-asahi-pins" ];

      xdg.desktopEntries.steam = {
        name = "Steam";
        genericName = "Games Store";
        exec = "${steam-asahi}/bin/steam-asahi";
        icon = "steam";
        terminal = false;
        categories = [
          "Network"
          "FileTransfer"
          "Game"
        ];
      };

      home.file = {
        "${steamRel}/steamapps/common/Counter-Strike Global Offensive/game/csgo/cfg/autoexec.cfg" = {
          force = true;
          text = ''
            // Venus can lose CS2's player-occlusion query pool during match load.
            r_csgo_player_occlusion_query 0
          '';
        };
        "${steamRel}/compatibilitytools.d/Box64-StickFight/compatibilitytool.vdf".text = ''
          "compatibilitytools"
          {
            "compat_tools"
            {
              "box64_stickfight"
              {
                "install_path" "."
                "display_name" "Box64 Stick Fight"
                "from_oslist" "windows"
                "to_oslist" "linux"
              }
            }
          }
        '';
        "${steamRel}/compatibilitytools.d/Box64-StickFight/toolmanifest.vdf".text = ''
          "manifest"
          {
            "commandline" "/proton run"
            "commandline_getnativepath" "/proton getnativepath"
            "commandline_getcompatpath" "/proton getcompatpath"
            "commandline_waitforexitandrun" "/proton waitforexitandrun"
          }
        '';
        "${steamRel}/compatibilitytools.d/Box64-StickFight/proton" = {
          executable = true;
          text = ''
            #!/bin/sh
            set -eu

            ACTION=''${1:-run}
            [ "$#" -eq 0 ] || shift
            case "$ACTION" in
              getnativepath|getcompatpath)
                printf '%s\n' "''${1:-}"
                exit 0
                ;;
              run|waitforexitandrun)
                ;;
              *)
                exit 2
                ;;
            esac
            [ "$#" -gt 0 ]
            GAME=$1
            export MESA_LOADER_DRIVER_OVERRIDE=zink
            export VK_DRIVER_FILES=/usr/share/vulkan/icd.d/virtio_icd.aarch64.json
            PROTON=${steam}/steamapps/common/Proton\ 10.0/files
            export WINEPREFIX=${steam}/steamapps/compatdata/674940/pfx
            export WINEDEBUG=-all
            export WINEDLLPATH="$PROTON/lib/vkd3d:$PROTON/lib/wine"
            export LD_LIBRARY_PATH="$PROTON/lib/x86_64-linux-gnu:$PROTON/lib/i386-linux-gnu:${x86-libgcc}/lib:/usr/lib64:/usr/lib:''${LD_LIBRARY_PATH:-}"
            unset LD_PRELOAD
            export SteamAppId=674940
            export SteamGameId=674940
            export BOX64_DYNAREC_STRONGMEM=1
            export BOX64_DYNAREC_BIGBLOCK=0
            export BOX64_NOGTK=1

            exec /usr/local/bin/box64 "$PROTON/bin/wine" \
              "$GAME" -force-d3d9 -popupwindow -screen-fullscreen 0
          '';
        };
      };

      home.activation.generateSteamGameEntries = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        ${steam-game-entries}/bin/steam-game-entries
      '';
    };
}
