{
  flake.homeModules.steamAsahi =
    {
      pkgs,
      lib,
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
                     | $c == "steam" or ($c | test("^steam_app_[0-9]+$")))
          ' >/dev/null 2>&1
        }

        CONTAINER=steam-asahi
        IMAGE=localhost/steam-asahi:44
        CFILE=Containerfile
        INI=distrobox.ini
      '';
      steam-asahi-doctor = pkgs.writeShellScriptBin "steam-asahi-doctor" ''
        set -eu
        ${shellHelpers}

        SOURCE=${config.home.homeDirectory}/nixos-config/steam-asahi

        [ "$(${pkgs.glibc.bin}/bin/getconf PAGESIZE)" = 16384 ]
        [ -r /dev/kvm ] && [ -w /dev/kvm ]
        ${pkgs.docker}/bin/docker image inspect "$IMAGE" >/dev/null
        ${pkgs.docker}/bin/docker container inspect "$CONTAINER" >/dev/null

        # Read out of the Containerfile rather than restated: a second copy of
        # the NEVRA list is one more thing to edit on every Fedora bump. Stops
        # at the first `dnf clean all` so only the base install list is read.
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
        printf '%s\n' "Steam Asahi container checks passed."
      '';

      # Every pin auto-bumps to the newest build in the repos; nothing is held
      # back. Names are derived from the NEVRAs rather than queried, because a
      # pin that has aged off the mirrors resolves to nothing and would then be
      # the one entry the updater could not fix -- which is the exact failure
      # this exists to prevent.
      update-steam-asahi-pins = pkgs.writeShellScriptBin "update-steam-asahi-pins" ''
        set -eu

        FILE=${config.home.homeDirectory}/nixos-config/steam-asahi/Containerfile
        ENTER="${pkgs.distrobox}/bin/distrobox enter --no-workdir steam-asahi --"

        if ! ${pkgs.docker}/bin/docker container inspect steam-asahi >/dev/null 2>&1; then
          printf '%-52s %s\n' steam-asahi "no container, skipped"
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

        # RPM forbids a dash in version and release, so dropping the arch
        # suffix and then the last two dash-fields leaves exactly the name.
        NAMES=$(
          printf '%s\n' "$PINS" \
            | ${pkgs.gnused}/bin/sed -e 's/\.[^.]*$//' -e 's/-[^-]*-[^-]*$//' \
            | ${pkgs.coreutils}/bin/sort -u
        )

        # Unquoted on purpose: the name list is the argument vector, and no
        # package name contains whitespace.
        # shellcheck disable=SC2086
        # %{version}-%{release}, not %{evr}: evr prefixes the epoch that the
        # pins omit, and NetworkManager (epoch 1) then never matches itself.
        # --arch keeps --latest-limit off the .src RPMs, which sort newest.
        # The format stays inline and quoted. Held in a variable it word-splits
        # on its own space, and dnf reads half the format as a package name.
        LATEST=$($ENTER dnf -q repoquery --available --arch aarch64,noarch --latest-limit 1 \
          --qf '%{name} %{name}-%{version}-%{release}.%{arch}\n' $NAMES 2>/dev/null || true)

        # An unreachable mirror returns nothing, which is indistinguishable from
        # "no package resolved" further down and would report all 34 pins as
        # retired. Pins are untouched either way, so this reports and leaves the
        # relock behind it alone rather than failing the whole `update`.
        if [ -z "$LATEST" ]; then
          printf 'steam-asahi pins\n  %s\n' \
            "could not reach the Fedora repos -- pins left untouched, rerun when back online"
          exit 0
        fi

        PLAN=$(printf '%s\n' "$PINS" | ${pkgs.gawk}/bin/awk -v latest="$LATEST" '
          BEGIN {
            n = split(latest, l, "\n")
            for (i = 1; i <= n; i++) { split(l[i], a, " "); if (a[1] != "") newest[a[1]] = a[2] }
          }
          $0 == "" { next }
          {
            nm = $0
            sub(/\.[^.]*$/, "", nm)
            sub(/-[^-]*-[^-]*$/, "", nm)
            # No entry at all means the package itself left the repos, not just
            # this build of it. Renamed or retired upstream, so only a human can
            # decide what replaces it.
            if (!(nm in newest)) { print "MISSING", $0, nm; next }
            if (newest[nm] == $0) { print "SAME", $0, "-"; next }
            print "BUMP", $0, newest[nm]
          }
        ')

        printf 'steam-asahi pins\n'

        TMP=$(${pkgs.coreutils}/bin/mktemp)
        ${pkgs.coreutils}/bin/cp "$FILE" "$TMP"
        # An arrow means that Containerfile line changed, and nothing else
        # prints one. The old output used the same arrow for held pins that
        # moved nothing, which is what made it unreadable.
        printf '%s\n' "$PLAN" | while read -r kind old new; do
          case $kind in
            BUMP)
              ${pkgs.gnused}/bin/sed -i "s|$old|$new|" "$TMP"
              printf '  %-52s -> %s\n' "$old" "$new"
              ;;
            SAME) printf '  %-52s    already newest\n' "$old" ;;
            MISSING) printf '  %-52s    !! package %s NO LONGER EXISTS in any enabled repo\n' "$old" "$new" ;;
          esac
        done

        BUMPED=$(printf '%s\n' "$PLAN" | ${pkgs.gnugrep}/bin/grep -c '^BUMP' || true)
        MISSED=$(printf '%s\n' "$PLAN" | ${pkgs.gnugrep}/bin/grep -c '^MISSING' || true)

        # Only rewrite when something actually moved, so an unchanged run
        # leaves the file's mtime and the container config hash alone.
        if [ "$BUMPED" -gt 0 ]; then
          # Written back through cat so the file keeps its own permissions.
          ${pkgs.coreutils}/bin/cat "$TMP" >"$FILE"
          printf '  %s\n' "$BUMPED pin(s) rewritten -- next game launch rebuilds the container"
        else
          printf '  %s\n' "every pin already newest, Containerfile untouched"
        fi
        if [ "$MISSED" -gt 0 ]; then
          printf '  %s\n' "$MISSED pin(s) CANNOT be fixed automatically -- the container will not rebuild until they are edited by hand in $FILE"
        fi
        ${pkgs.coreutils}/bin/rm -f "$TMP"
      '';

      steam-asahi-bootstrap = pkgs.writeShellScriptBin "steam-asahi-bootstrap" ''
        set -eu

        ${shellHelpers}

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
          # Not `--replace`: docker rm returns before the removal completes, so
          # distrobox's immediate create loses the race and leaves a container
          # it never runs its user-adding init on. Every later enter then fails
          # with "unable to find user uynx: no matching entries in passwd file".
          ${pkgs.docker}/bin/docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
          for _ in $(${pkgs.coreutils}/bin/seq 1 60); do
            ${pkgs.docker}/bin/docker container inspect "$CONTAINER" \
              >/dev/null 2>&1 || break
            sleep 1
          done
          ${pkgs.distrobox}/bin/distrobox assemble create \
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
      fex-hogwarts-config = pkgs.writeText "fex-hogwarts.json" (
        builtins.toJSON {
          Config = {
            SMCChecks = "full";
            StrictInProcessSplitLocks = true;
            Multiblock = false;
          };
          ThunksDB = { };
        }
      );

      steam-asahi-remote = pkgs.writeShellScriptBin "steam-asahi-remote" ''
        set -eu
        ${shellHelpers}

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

        exec ${pkgs.distrobox}/bin/distrobox enter --no-workdir "$CONTAINER" -- \
          /usr/bin/muvm -i -- "$STEAM_BIN" "$URL"
      '';

      steam-asahi-run = pkgs.writeShellScriptBin "steam-asahi-run" ''
        set -eu
        ${shellHelpers}

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
        # MangoHud and gtk2 come from the nix store rather than either image's
        # package manager, because asahi-alarm ships neither and /nix is visible
        # in both containers. The layer must sit in the standard directory —
        # pressure-vessel only captures layers it finds on that search path.
        # The gtk2 link is gated so it cannot shadow Fedora's own copy, which
        # lives in /usr/lib64 with /usr/lib symlinked onto it.
        ${pkgs.distrobox}/bin/distrobox enter --no-workdir "$CONTAINER" -- sudo sh -c \
          'grep -qs " /usr/share/guestos/fex-mesa " /proc/mounts || {
             mkdir -p /usr/share/guestos/fex-mesa
             mount -o loop,ro /home/uynx/.local/share/steam-asahi/ArchLinux.ero \
               /usr/share/guestos/fex-mesa
           }
           install -Dm444 \
             ${pkgs.mangohud}/share/vulkan/implicit_layer.d/MangoHud.aarch64.json \
             /usr/share/vulkan/implicit_layer.d/MangoHud.aarch64.json
           ldconfig -p | grep -q libgtk-x11-2.0.so.0 || ln -sfn \
             ${pkgs.gtk2}/lib/libgtk-x11-2.0.so.0 \
             ${pkgs.gtk2}/lib/libgdk-x11-2.0.so.0 /usr/lib/'

        # No compat tool is written from here: Steam Play is set once in the
        # client (all titles -> Proton ARM64 Experimental), which is native
        # aarch64 Wine with FEX translating only the game's own x86.


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


        # Only the aarch64 Proton path gets the HUD: the x86 one draws through
        # the read-only FEX rootfs, which carries no MangoHud to load. Games see
        # raw pixels rather than niri's logical size, so the default 24px font
        # renders at half the size it looks like it should on this display.
        set -- /usr/bin/muvm \
          -e "BROWSER=$GUEST_BIN/xdg-open" \
          -e "MANGOHUD=''${STEAM_HUD:-0}" \
          -e "MANGOHUD_CONFIG=font_size=''${STEAM_HUD_FONT:-48}" \
          --gpu-mode=venus
        # Proton writes ~/steam-<appid>.log in the guest home when this is set.
        if [ -n "''${STEAM_PROTON_LOG:-}" ]; then
          set -- "$@" -e "PROTON_LOG=1"
        fi
        if [ "$APP_ID" = 990080 ]; then
          set -- "$@" --vram=4096
          # Per-game FEX tuning. Passed here rather than through Steam's launch
          # options, which live in localconfig.vdf and are rewritten by Steam.
          set -- "$@" -e "FEX_APP_CONFIG=${fex-hogwarts-config}"
        fi
        set -- "$@" --execute-pre=/usr/local/libexec/steam-guest-tune -- \
          "$STEAM_BIN"
        if [ -n "$APP_ID" ]; then
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
        APP=steam_app_$APP_ID
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

      # No per-game display handling: niri's window rules fullscreen every
      # steam_app_* window, and ARM64 Proton removed the reason the games each
      # needed their resolution written into their own config format.
      steam-launch = pkgs.writeShellScriptBin "steam-launch" ''
        set -eu
        ${shellHelpers}

        APP_ID=$1
        case "$APP_ID" in
          *[!0-9]*|"") exit 2 ;;
        esac

        APP=steam_app_$APP_ID
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

      steam-menu = pkgs.writers.writeDashBin "steam-menu" ''
        ${steam-game-entries}/bin/steam-game-entries
        exec ${pkgs.noctalia-shell}/bin/noctalia-shell ipc call launcher toggle
      '';

      # Bound to Mod+W and Mod+Q. niri's close-window is wrong for Steam: closing
      # the XWayland window leaves Proton and the game running headless in the VM.
      close-active = pkgs.writers.writeDashBin "close-active" ''
        set -eu

        ACTIVE=$(${N} msg -j focused-window 2>/dev/null || echo '{}')
        APP=$(printf '%s' "$ACTIVE" | ${J} -r '.app_id // ""' 2>/dev/null || true)
        case "$APP" in
          steam|Steam|steam_app_[0-9]*)
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
        update-steam-asahi-pins
        distrobox
        dive
        close-active
      ];

      # Rewrites the Containerfile but never installs: `update` runs its hooks
      # as `; or return 1`, so a container rebuild failing on a Fedora mirror
      # hiccup would abort the flake relock behind it.
      shellHooks.update = [ "update-steam-asahi-pins" ];

      # Installing the bumped pins is instead reb's job, after a successful
      # switch, where a failure cannot wedge anything. Bootstrap self-gates on
      # the Containerfile hash, so this is a sub-second no-op on the rebuilds
      # that did not touch it -- which is nearly all of them. Without this the
      # first launch after a bump pays for a 34-package dnf install, and a bad
      # bump surfaces mid-launch instead of here.
      shellHooks.rebPostSwitch = ''
        ${steam-asahi-bootstrap}/bin/steam-asahi-bootstrap
        or echo "steam-asahi container rebuild failed -- run steam-asahi-bootstrap by hand"
      '';

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

      home.activation.generateSteamGameEntries = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        ${steam-game-entries}/bin/steam-game-entries
      '';
    };
}
