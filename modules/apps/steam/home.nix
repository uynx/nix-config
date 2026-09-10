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

      guestRel = ".local/share/steam-asahi/home";
      steamRel = "${guestRel}/.local/share/Steam";
      guest = "${config.home.homeDirectory}/${guestRel}";
      steam = "${config.home.homeDirectory}/${steamRel}";

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
        CFILE=Containerfile
        INI=distrobox.ini

        REL=$(${pkgs.gnugrep}/bin/grep -om1 '\.fc[0-9][0-9]*' \
          ${config.home.homeDirectory}/nix-config/steam-asahi/Containerfile \
          | ${pkgs.gnused}/bin/sed 's/\.fc//')
        IMAGE=localhost/steam-asahi:$REL
      '';
      steam-asahi-doctor = pkgs.writeShellScriptBin "steam-asahi-doctor" ''
        set -eu
        ${shellHelpers}

        SOURCE=${config.home.homeDirectory}/nix-config/steam-asahi

        [ "$(${pkgs.glibc.bin}/bin/getconf PAGESIZE)" = 16384 ]
        [ -r /dev/kvm ] && [ -w /dev/kvm ]
        ${pkgs.docker}/bin/docker image inspect "$IMAGE" >/dev/null
        ${pkgs.docker}/bin/docker container inspect "$CONTAINER" >/dev/null

        ${pkgs.gawk}/bin/awk -v rel="fc$REL" '
          /dnf install -y/ { f = 1 }
          f && $0 ~ rel { gsub(/['"'"' \\&]/, ""); print }
          /dnf clean all/ { exit }
        ' "$SOURCE/Containerfile" \
          | ${pkgs.findutils}/bin/xargs \
            ${pkgs.distrobox}/bin/distrobox enter --no-tty "$CONTAINER" -- rpm -q >/dev/null
        ${pkgs.distrobox}/bin/distrobox enter --no-tty "$CONTAINER" -- \
          test -e /usr/lib64/dri/asahi_dri.so
        ${pkgs.distrobox}/bin/distrobox enter --no-tty "$CONTAINER" -- \
          test -e /usr/lib64/libvulkan_asahi.so
        ${pkgs.distrobox}/bin/distrobox enter --no-tty "$CONTAINER" -- \
          test -x /opt/steam-arm64/steamrtarm64/steam
        printf '%s\n' "Steam Asahi container checks passed."
      '';

      update-steam-asahi-pins = pkgs.writeShellScriptBin "update-steam-asahi-pins" ''
        set -eu

        FILE=${config.home.homeDirectory}/nix-config/steam-asahi/Containerfile
        DOCKER=${pkgs.docker}/bin/docker

        REPO=$(${pkgs.gnused}/bin/sed -n 's|^FROM \([^@:]*\).*|\1|p' "$FILE" | ${pkgs.coreutils}/bin/head -1)
        RELEASE=$(${pkgs.gnugrep}/bin/grep -om1 '\.fc[0-9][0-9]*' "$FILE" | ${pkgs.gnused}/bin/sed 's/\.fc//')
        OLD_BASE=$(${pkgs.gnused}/bin/sed -n 's|^FROM .*@\(sha256:[0-9a-f]*\).*|\1|p' "$FILE" | ${pkgs.coreutils}/bin/head -1)

        printf 'steam-asahi pins\n'

        if ! ERR=$(${pkgs.coreutils}/bin/timeout 600 $DOCKER pull -q "$REPO:$RELEASE" 2>&1 >/dev/null); then
          printf '  %s\n' "could not pull $REPO:$RELEASE -- pins left untouched" "$ERR"
          exit 0
        fi
        NEW_BASE=$($DOCKER image inspect "$REPO:$RELEASE" \
          --format '{{index .RepoDigests 0}}' | ${pkgs.gnused}/bin/sed 's|.*@||')

        TMP=$(${pkgs.coreutils}/bin/mktemp)
        ${pkgs.coreutils}/bin/cp "$FILE" "$TMP"
        BUMPED=0

        if [ "$NEW_BASE" != "$OLD_BASE" ]; then
          ${pkgs.gnused}/bin/sed -i "s|$OLD_BASE|$NEW_BASE|" "$TMP"
          printf '  %-52s -> %s\n' "base image $OLD_BASE" "$NEW_BASE"
          BUMPED=$((BUMPED + 1))
        fi

        PINS=$(
          ${pkgs.gawk}/bin/awk -v rel="fc$RELEASE" '
            /dnf install -y/ { f = 1 }
            f && $0 ~ rel {
              line = $0
              gsub(/['"'"' \\&]/, "", line)
              if (!seen[line]++) print line
            }
            /dnf clean all/ { f = 0 }
          ' "$FILE"
        )

        NAMES=$(
          printf '%s\n' "$PINS" \
            | ${pkgs.gnused}/bin/sed -e 's/\.[^.]*$//' -e 's/-[^-]*-[^-]*$//' \
            | ${pkgs.coreutils}/bin/sort -u \
            | ${pkgs.coreutils}/bin/tr '\n' ' '
        )

        if $DOCKER container inspect steam-asahi >/dev/null 2>&1; then
          LATEST=$(${pkgs.coreutils}/bin/timeout 240 \
            ${pkgs.distrobox}/bin/distrobox enter --no-tty --no-workdir steam-asahi -- \
            dnf -q repoquery --available --arch aarch64,noarch --latest-limit 1 \
            --setopt=timeout=30 --setopt=retries=3 \
            --qf '%{name} %{name}-%{version}-%{release}.%{arch}\n' $NAMES \
            < /dev/null 2>/dev/null || true)
        else
          QC=steam-asahi-pinquery-$$
          trap '$DOCKER rm -f "$QC" >/dev/null 2>&1 || true' EXIT

          LATEST=$(${pkgs.coreutils}/bin/timeout 900 $DOCKER run --rm --name "$QC" "$REPO@$NEW_BASE" sh -c "
            dnf install -y 'dnf5-command(copr)' >/dev/null 2>&1 &&
            dnf copr enable -y @asahi/fedora-remix-scripts >/dev/null 2>&1 &&
            dnf copr enable -y @asahi/steam >/dev/null 2>&1 &&
            dnf -q repoquery --available --arch aarch64,noarch --latest-limit 1 \
              --setopt=timeout=30 --setopt=retries=3 \
              --qf '%{name} %{name}-%{version}-%{release}.%{arch}\n' $NAMES
          " 2>/dev/null || true)
        fi

        if [ -z "$LATEST" ]; then
          printf '  %s\n' "could not reach the Fedora repos -- package pins left untouched, rerun when back online"
        else
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
              if (!(nm in newest)) { print "MISSING", $0, nm; next }
              if (newest[nm] == $0) { print "SAME", $0, "-"; next }
              print "BUMP", $0, newest[nm]
            }
          ')

          MISSED=$(printf '%s\n' "$PLAN" | ${pkgs.gnugrep}/bin/grep -c '^MISSING' || true)

          if [ "$MISSED" -gt 3 ]; then
            printf '  %s\n' "$MISSED of $(printf '%s\n' "$PINS" | ${pkgs.coreutils}/bin/wc -l) pins unresolved -- a repo failed to load, package pins left untouched"
          else
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

            BUMPED=$((BUMPED + $(printf '%s\n' "$PLAN" | ${pkgs.gnugrep}/bin/grep -c '^BUMP' || true)))
            if [ "$MISSED" -gt 0 ]; then
              printf '  %s\n' "$MISSED pin(s) CANNOT be fixed automatically -- the container will not rebuild until they are edited by hand in $FILE"
            fi
          fi
        fi

        if [ "$BUMPED" -gt 0 ]; then
          ${pkgs.coreutils}/bin/cat "$TMP" >"$FILE"
          printf '  %s\n' "$BUMPED pin(s) rewritten -- reb will rebuild the container"
        else
          printf '  %s\n' "every pin already newest, Containerfile untouched"
        fi
        ${pkgs.coreutils}/bin/rm -f "$TMP"
      '';

      steam-asahi-bootstrap = pkgs.writeShellScriptBin "steam-asahi-bootstrap" ''
        set -eu

        ${shellHelpers}

        SOURCE=${config.home.homeDirectory}/nix-config/steam-asahi
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
            --network=host \
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
          ${pkgs.docker}/bin/docker container inspect \
            --format '{{range .HostConfig.Binds}}{{println .}}{{end}}' "$CONTAINER" \
            | ${pkgs.gnugrep}/bin/grep -q "^${pkgs.distrobox}/bin/distrobox-init:" \
            || REPLACE=1
        fi
        if [ "$REPLACE" = 1 ] || \
           { [ -n "''${CONTAINER_IMAGE_ID:-}" ] && [ "$CONTAINER_IMAGE_ID" != "$IMAGE_ID" ]; }; then
          ${pkgs.docker}/bin/docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
          for _ in $(${pkgs.coreutils}/bin/seq 1 60); do
            ${pkgs.docker}/bin/docker container inspect "$CONTAINER" \
              >/dev/null 2>&1 || break
            sleep 1
          done
          ${pkgs.distrobox}/bin/distrobox assemble create \
            --file "$SOURCE/$INI"
        fi

        ${pkgs.distrobox}/bin/distrobox enter --no-tty "$CONTAINER" -- \
          test -x /opt/steam-arm64/steamrtarm64/steam
      '';

      steam-asahi-stop = pkgs.writeShellScriptBin "steam-asahi-stop" ''
        set -eu
        ${shellHelpers}

        RUNTIME_DIR=''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
        if [ "$(${pkgs.docker}/bin/docker container inspect \
          --format '{{.State.Running}}' "$CONTAINER" 2>/dev/null || true)" = true ]; then
          ${pkgs.docker}/bin/docker container stop --time 5 "$CONTAINER" >/dev/null
        fi

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

        rm -rf \
          "$RUNTIME_DIR/krun" \
          "$RUNTIME_DIR/muvm.lock"
        rm -f \
          ${guest}/.cache/steam-asahi/open-url.pipe \
          ${guest}/.steam/steam.pipe
      '';

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

        exec ${pkgs.distrobox}/bin/distrobox enter --no-tty --no-workdir "$CONTAINER" -- \
          /usr/bin/muvm -i -- "$STEAM_BIN" "$URL"
      '';

      steam-asahi-run = pkgs.writeShellScriptBin "steam-asahi-run" ''
        set -eu
        ${shellHelpers}

        APP_ID=''${1:-}

        ${steam-asahi-bootstrap}/bin/steam-asahi-bootstrap

        ROOTFS=/home/uynx/.local/share/steam-asahi/ArchLinux.ero
        if [ ! -e "$ROOTFS" ]; then
          ${pkgs.curl}/bin/curl -fsSL --retry 3 --retry-all-errors --retry-delay 5 \
            --connect-timeout 10 --speed-limit 1024 --speed-time 60 \
            -o "$ROOTFS.part" \
            https://rootfs.fex-emu.gg/ArchLinux/2026-08-11/ArchLinux.ero
          echo "b035dcfe31a3d8e7ee497f2809caa11bf3a85bc68d707c7621d7433839d19ff2  $ROOTFS.part" \
            | ${pkgs.coreutils}/bin/sha256sum -c -
          ${pkgs.coreutils}/bin/mv "$ROOTFS.part" "$ROOTFS"
        fi
        ${pkgs.distrobox}/bin/distrobox enter --no-tty --no-workdir "$CONTAINER" -- sudo sh -c \
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
          ${pkgs.distrobox}/bin/distrobox enter --no-tty --no-workdir "$CONTAINER" -- \
            cp -a /opt/steam-arm64/steamrtarm64 "$STEAM_ROOT/" < /dev/null
        fi
        mkdir -p "$STEAM_ROOT/package" "$STEAM_HOME"
        printf '%s\n' "''${STEAM_CLIENT_BRANCH-publicbeta}" >"$STEAM_ROOT/package/beta"
        ln -sfn "$STEAM_ROOT" "$STEAM_HOME/root"
        ln -sfn "$STEAM_ROOT" "$STEAM_HOME/steam"
        ln -sfn "$STEAM_ROOT/linuxarm64" "$STEAM_HOME/sdkarm64"
        chmod -R u+rwX "$STEAM_ROOT/steamrtarm64"

        if [ -n "$APP_ID" ]; then
          case "$APP_ID" in
            *[!0-9]*) exit 2 ;;
          esac
        fi

        set -- /usr/bin/muvm \
          -e "BROWSER=$GUEST_BIN/xdg-open" \
          -e "MANGOHUD=''${STEAM_HUD:-0}" \
          -e "MANGOHUD_CONFIG=font_size=''${STEAM_HUD_FONT:-48}" \
          --gpu-mode=venus
        if [ -n "''${STEAM_PROTON_LOG:-}" ]; then
          set -- "$@" -e "PROTON_LOG=1"
        fi
        if [ "$APP_ID" = 990080 ]; then
          set -- "$@" --vram=4096
          set -- "$@" -e "FEX_APP_CONFIG=${fex-hogwarts-config}"
        fi
        set -- "$@" --execute-pre=/usr/local/libexec/steam-guest-tune -- \
          "$STEAM_BIN"
        if [ -n "$APP_ID" ]; then
          set -- "$@" -silent -applaunch "$APP_ID"
        fi

        STATUS=0
        ${pkgs.distrobox}/bin/distrobox enter --no-tty --no-workdir "$CONTAINER" -- "$@" || STATUS=$?
        ${steam-asahi-stop}/bin/steam-asahi-stop
        exit "$STATUS"
      '';

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

    in
    {
      home.packages = with pkgs; [
        steam-asahi
        steam-asahi-bootstrap
        steam-asahi-doctor
        steam-asahi-stop
        steam-menu
        update-steam-asahi-pins
        distrobox
        dive
      ];

      shellHooks.update = [ "update-steam-asahi-pins" ];

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
