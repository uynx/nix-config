{
  flake.homeModules.steamFex =
    {
      pkgs,
      lib,
      config,
      ...
    }:

    let
      N = "${lib.getExe pkgs.niri}";
      J = "${lib.getExe pkgs.jq}";

      guestRel = ".local/share/steam-arm/home";
      steamRel = "${guestRel}/.local/share/Steam";
      guest = "${config.home.homeDirectory}/${guestRel}";
      steam = "${config.home.homeDirectory}/${steamRel}";

      shellHelpers = ''
        window_id() {
          ${N} msg -j windows 2>/dev/null | ${J} -r --arg app "$1" \
            '[.[] | select(((.app_id // "") | ascii_downcase) == $app) | .id][0] // empty' \
            2>/dev/null || true
        }

        CONTAINER_APPS='${builtins.toJSON (lib.mapAttrsToList (_: a: lib.toLower a.name) (config.x86Apps or { }))}'
        CONTAINER_APP='$c == "steam" or ($c | test("^steam_app_[0-9]+$")) or ($c | IN($ids[]))'

        is_container_app() {
          ${J} -n -e --argjson ids "$CONTAINER_APPS" --arg c "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" "$CONTAINER_APP" >/dev/null
        }

        any_steam_window() {
          ${N} msg -j windows 2>/dev/null | ${J} -e --argjson ids "$CONTAINER_APPS" \
            "any(.[]; ((.app_id // \"\") | ascii_downcase) as \$c | $CONTAINER_APP)" >/dev/null 2>&1
        }

        CONTAINER=steam-arm
        CFILE=Containerfile
        INI=distrobox.ini

        REL=$(${pkgs.gnugrep}/bin/grep -om1 '\.fc[0-9][0-9]*' \
          ${config.home.homeDirectory}/nix-config/modules/apps/steam/fex/Containerfile \
          | ${pkgs.gnused}/bin/sed 's/\.fc//')
        IMAGE=localhost/steam-arm:$REL
      '';
      steam-arm-doctor = pkgs.writeShellScriptBin "steam-arm-doctor" ''
        set -eu
        ${shellHelpers}

        SOURCE=${config.home.homeDirectory}/nix-config/modules/apps/steam/fex

        ${pkgs.podman}/bin/podman image inspect "$IMAGE" >/dev/null
        ${pkgs.podman}/bin/podman container inspect "$CONTAINER" >/dev/null

        ${pkgs.gawk}/bin/awk -v rel="fc$REL" '
          /dnf install -y/ { f = 1 }
          f && $0 ~ rel { gsub(/['"'"' \\&]/, ""); print }
          /^$/ { f = 0 }
        ' "$SOURCE/Containerfile" \
          | ${pkgs.findutils}/bin/xargs \
            ${pkgs.distrobox}/bin/distrobox enter --no-tty "$CONTAINER" -- rpm -q >/dev/null
        ${pkgs.distrobox}/bin/distrobox enter --no-tty "$CONTAINER" -- sh -c '
          test -e /usr/lib64/libvulkan_freedreno.so &&
          test -e /usr/share/fex-emu/RootFS/default.erofs &&
          test "$(/usr/bin/FEX /usr/bin/uname -m 2>/dev/null)" = x86_64 &&
          test -x /opt/steam-arm64/steamrtarm64/steam &&
          ls /dev/dri/renderD* >/dev/null' </dev/null
        printf '%s\n' "Steam ARM container checks passed."
      '';

      update-steam-arm-pins = pkgs.writeShellScriptBin "update-steam-arm-pins" ''
        set -eu

        FILE=${config.home.homeDirectory}/nix-config/modules/apps/steam/fex/Containerfile
        PODMAN=${pkgs.podman}/bin/podman

        REPO=$(${pkgs.gnused}/bin/sed -n 's|^FROM \([^@:]*\).*|\1|p' "$FILE" | ${pkgs.coreutils}/bin/head -1)
        RELEASE=$(${pkgs.gnugrep}/bin/grep -om1 '\.fc[0-9][0-9]*' "$FILE" | ${pkgs.gnused}/bin/sed 's/\.fc//')
        OLD_BASE=$(${pkgs.gnused}/bin/sed -n 's|^FROM .*@\(sha256:[0-9a-f]*\).*|\1|p' "$FILE" | ${pkgs.coreutils}/bin/head -1)

        printf 'steam-arm pins\n'

        if ! ERR=$(${pkgs.coreutils}/bin/timeout 600 $PODMAN pull -q "$REPO:$RELEASE" 2>&1 >/dev/null); then
          printf '  %s\n' "could not pull $REPO:$RELEASE -- pins left untouched" "$ERR"
          exit 0
        fi
        NEW_BASE=$($PODMAN image inspect "$REPO:$RELEASE" \
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
            /^$/ { f = 0 }
          ' "$FILE"
        )

        NAMES=$(
          printf '%s\n' "$PINS" \
            | ${pkgs.gnused}/bin/sed -e 's/\.[^.]*$//' -e 's/-[^-]*-[^-]*$//' \
            | ${pkgs.coreutils}/bin/sort -u \
            | ${pkgs.coreutils}/bin/tr '\n' ' '
        )

        if $PODMAN container inspect steam-arm >/dev/null 2>&1; then
          LATEST=$(${pkgs.coreutils}/bin/timeout 240 \
            ${pkgs.distrobox}/bin/distrobox enter --no-tty --no-workdir steam-arm -- \
            dnf -q repoquery --available --arch aarch64,noarch --latest-limit 1 \
            --setopt=timeout=30 --setopt=retries=3 \
            --qf '%{name} %{name}-%{version}-%{release}.%{arch}\n' $NAMES \
            < /dev/null 2>/dev/null || true)
        else
          QC=steam-arm-pinquery-$$
          trap '$PODMAN rm -f "$QC" >/dev/null 2>&1 || true' EXIT

          LATEST=$(${pkgs.coreutils}/bin/timeout 900 $PODMAN run --rm --name "$QC" "$REPO@$NEW_BASE" sh -c "
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

      steam-arm-bootstrap = pkgs.writeShellScriptBin "steam-arm-bootstrap" ''
        set -eu

        ${shellHelpers}

        LOCK="/run/user/$(${pkgs.coreutils}/bin/id -u)/steam-arm-bootstrap.lock"
        exec 9>"$LOCK"
        ${pkgs.util-linux}/bin/flock 9

        SOURCE=${config.home.homeDirectory}/nix-config/modules/apps/steam/fex
        LABEL=io.uynx.steam-arm.config

        if [ ! -f "$SOURCE/$CFILE" ] || [ ! -f "$SOURCE/$INI" ]; then
          ${pkgs.libnotify}/bin/notify-send \
            "Steam setup unavailable" \
            "Missing the versioned steam-arm container files."
          exit 1
        fi

        CONFIG_HASH=$(
          ${pkgs.coreutils}/bin/sha256sum \
            "$SOURCE/$CFILE" "$SOURCE/$INI" \
            | ${pkgs.coreutils}/bin/sha256sum \
            | ${pkgs.coreutils}/bin/cut -d' ' -f1
        )
        IMAGE_HASH=$(
          ${pkgs.podman}/bin/podman image inspect \
            --format "{{ index .Config.Labels \"$LABEL\" }}" \
            "$IMAGE" 2>/dev/null || true
        )
        REPLACE=0

        if [ "$IMAGE_HASH" != "$CONFIG_HASH" ]; then
          ${pkgs.podman}/bin/podman build \
            --network=host \
            --label "$LABEL=$CONFIG_HASH" \
            --tag "$IMAGE" \
            --file "$SOURCE/$CFILE" \
            "$SOURCE"
          REPLACE=1
        fi

        IMAGE_ID=$(
          ${pkgs.podman}/bin/podman image inspect \
            --format '{{.Id}}' "$IMAGE"
        )
        if ! ${pkgs.podman}/bin/podman container inspect "$CONTAINER" >/dev/null 2>&1; then
          ${pkgs.distrobox}/bin/distrobox assemble create \
            --file "$SOURCE/$INI" 9>&-
          REPLACE=0
        else
          CONTAINER_IMAGE_ID=$(
            ${pkgs.podman}/bin/podman container inspect \
              --format '{{.Image}}' "$CONTAINER"
          )
          ${pkgs.podman}/bin/podman container inspect \
            --format '{{range .HostConfig.Binds}}{{println .}}{{end}}' "$CONTAINER" \
            | ${pkgs.gnugrep}/bin/grep -q "^${pkgs.distrobox}/bin/distrobox-init:" \
            || REPLACE=1
        fi
        if [ "$REPLACE" = 1 ] || \
           { [ -n "''${CONTAINER_IMAGE_ID:-}" ] && [ "$CONTAINER_IMAGE_ID" != "$IMAGE_ID" ]; }; then
          ${pkgs.podman}/bin/podman rm -f "$CONTAINER" >/dev/null 2>&1 || true
          for _ in $(${pkgs.coreutils}/bin/seq 1 60); do
            ${pkgs.podman}/bin/podman container inspect "$CONTAINER" \
              >/dev/null 2>&1 || break
            sleep 1
          done
          ${pkgs.distrobox}/bin/distrobox assemble create \
            --file "$SOURCE/$INI" 9>&-
        fi

        # 9>&-: conmon inherits open fds and would hold the lock for the container's lifetime.
        ${pkgs.distrobox}/bin/distrobox enter --no-tty "$CONTAINER" -- \
          test -x /opt/steam-arm64/steamrtarm64/steam 9>&-
      '';

      steam-arm-stop = pkgs.writeShellScriptBin "steam-arm-stop" ''
        set -eu
        ${shellHelpers}

        if [ "''${1:-}" = --closed ]; then
          is_container_app "$3" || exit 0
          for _ in $(${pkgs.coreutils}/bin/seq 1 20); do
            ${N} msg -j windows | ${J} -e --argjson id "$2" 'any(.[]; .id == $id)' >/dev/null || break
            sleep 0.5
          done
          [ -z "$(window_id "$(printf '%s' "$3" | tr '[:upper:]' '[:lower:]')")" ] || exit 0
          [ "''${4:-}" = quit ] || exit 0
          any_steam_window && exit 0
        fi

        # x86 app launchers carry their x86-apps/ home on the distrobox command line.
        if ! ${pkgs.procps}/bin/pgrep -f 'distrobox.* steam-arm .*/x86-apps/' >/dev/null && \
           [ "$(${pkgs.podman}/bin/podman container inspect \
             --format '{{.State.Running}}' "$CONTAINER" 2>/dev/null || true)" = true ]; then
          ${pkgs.podman}/bin/podman container stop --time 5 "$CONTAINER" >/dev/null
        fi

        RUNTIME_DIR=''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
        for LOCK in "$RUNTIME_DIR"/steam-arm-launch-*; do
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

        rm -f \
          ${guest}/.cache/steam-arm/open-url.pipe \
          ${guest}/.steam/steam.pipe
      '';

      steam-guest-open = pkgs.writeShellScript "steam-guest-open" ''
        set -eu

        FIFO=${guest}/.cache/steam-arm/open-url.pipe
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

      steam-arm-remote = pkgs.writeShellScriptBin "steam-arm-remote" ''
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
          "$STEAM_BIN" "$URL" </dev/null
      '';

      steam-arm-run = pkgs.writeShellScriptBin "steam-arm-run" ''
        set -eu
        ${shellHelpers}

        APP_ID=''${1:-}
        if [ -n "$APP_ID" ]; then
          case "$APP_ID" in
            *[!0-9]*) exit 2 ;;
          esac
        fi

        ${steam-arm-bootstrap}/bin/steam-arm-bootstrap

        ${pkgs.distrobox}/bin/distrobox enter --no-tty --no-workdir "$CONTAINER" -- sudo install -Dm444 \
          ${pkgs.mangohud}/share/vulkan/implicit_layer.d/MangoHud.aarch64.json \
          /usr/share/vulkan/implicit_layer.d/MangoHud.aarch64.json </dev/null

        STEAM_ROOT=${steam}
        STEAM_HOME=${guest}/.steam
        STEAM_BIN="$STEAM_ROOT/steamrtarm64/steam"
        GUEST_BIN=${guest}/.local/bin
        URL_FIFO=${guest}/.cache/steam-arm/open-url.pipe

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

        set -- env \
          "BROWSER=$GUEST_BIN/xdg-open" \
          "MANGOHUD=''${STEAM_HUD:-0}" \
          "MANGOHUD_CONFIG=font_size=''${STEAM_HUD_FONT:-48}"
        if [ -n "''${STEAM_PROTON_LOG:-}" ]; then
          set -- "$@" PROTON_LOG=1
        fi
        set -- "$@" "$STEAM_BIN"
        if [ -n "$APP_ID" ]; then
          set -- "$@" -silent -applaunch "$APP_ID"
        fi

        STATUS=0
        ${pkgs.distrobox}/bin/distrobox enter --no-tty --no-workdir "$CONTAINER" -- "$@" </dev/null || STATUS=$?
        ${steam-arm-stop}/bin/steam-arm-stop
        exit "$STATUS"
      '';

      steam-arm = pkgs.writeShellScriptBin "steam-arm" ''
        set -eu
        ${shellHelpers}

        STEAM_ID=$(window_id steam)
        if [ -n "$STEAM_ID" ]; then
          exec ${N} msg action focus-window --id "$STEAM_ID"
        fi

        if [ "$(${pkgs.podman}/bin/podman container inspect \
          --format '{{.State.Running}}' "$CONTAINER" 2>/dev/null || true)" = true ] && \
           [ -p ${guest}/.steam/steam.pipe ]; then
          ${steam-arm-remote}/bin/steam-arm-remote ui || true
          for _ in $(${pkgs.coreutils}/bin/seq 1 50); do
            STEAM_ID=$(window_id steam)
            if [ -n "$STEAM_ID" ]; then
              exec ${N} msg action focus-window --id "$STEAM_ID"
            fi
            sleep 0.1
          done
          exit 0
        fi

        exec ${steam-arm-run}/bin/steam-arm-run "$@"
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
          any_steam_window || ${steam-arm-stop}/bin/steam-arm-stop
          exit 0
        fi

        ${N} msg action focus-window --id "$ID" >/dev/null 2>&1 || true

        while [ -n "$(window_id "$APP")" ]; do
          sleep 0.5
        done
        sleep 1

        any_steam_window || ${steam-arm-stop}/bin/steam-arm-stop
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

        LOCK="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/steam-arm-launch-$APP_ID"
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

        CONTAINER_RUNNING=$(${pkgs.podman}/bin/podman container inspect \
          --format '{{.State.Running}}' "$CONTAINER" 2>/dev/null || true)
        if [ "$CONTAINER_RUNNING" = true ]; then
          for _ in $(${pkgs.coreutils}/bin/seq 1 100); do
            [ -p ${guest}/.steam/steam.pipe ] && break
            sleep 0.1
          done
          if [ -p ${guest}/.steam/steam.pipe ]; then
            ${steam-arm-remote}/bin/steam-arm-remote "$APP_ID"
            exit 0
          fi

          if [ -n "$(window_id steam)" ]; then
            ${pkgs.libnotify}/bin/notify-send \
              "Steam game not launched" \
              "Steam is still starting; try again in a moment."
            exit 1
          fi
        fi

        exec ${steam-arm-run}/bin/steam-arm-run "$APP_ID"
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
        steam-arm
        steam-arm-bootstrap
        steam-arm-doctor
        steam-arm-stop
        steam-menu
        update-steam-arm-pins
        distrobox
        dive
      ];

      home.sessionVariables.DOCKER_HOST = "unix://$XDG_RUNTIME_DIR/podman/podman.sock";

      shellHooks.update = [ "update-steam-arm-pins" ];

      shellHooks.rebPostSwitch = ''
        ${steam-arm-bootstrap}/bin/steam-arm-bootstrap
        or echo "steam-arm container rebuild failed -- run steam-arm-bootstrap by hand"
      '';

      xdg.desktopEntries.steam = {
        name = "Steam";
        genericName = "Games Store";
        exec = "${steam-arm}/bin/steam-arm";
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
