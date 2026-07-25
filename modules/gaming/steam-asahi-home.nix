{
  flake.homeModules.steamAsahi =
    {
      config,
      pkgs,
      lib,
      inputs,
      ...
    }:

    let
      home = "/home/uynx";
      H = "${pkgs.hyprland}/bin/hyprctl";
      J = "${pkgs.jq}/bin/jq";
    x86-pkgs = import inputs.nixpkgs {
      system = "x86_64-linux";
      config.allowUnfree = true;
    };
    x86-libgcc = x86-pkgs.stdenv.cc.cc.lib;
    steam-asahi-doctor = pkgs.writeShellScriptBin "steam-asahi-doctor" ''
      set -eu

      IMAGE=localhost/steam-asahi:44
      CONTAINER=steam-asahi

      [ "$(${pkgs.glibc.bin}/bin/getconf PAGESIZE)" = 16384 ]
      [ -r /dev/kvm ] && [ -w /dev/kvm ]
      ${pkgs.docker}/bin/docker image inspect "$IMAGE" >/dev/null
      ${pkgs.docker}/bin/docker container inspect "$CONTAINER" >/dev/null
      ${pkgs.distrobox}/bin/distrobox enter "$CONTAINER" -- rpm -q \
        asahi-platform-metapackage-fex-0-29.fc44.aarch64 \
        muvm-0.6.0-3.fc44.aarch64 \
        fex-emu-2604-1.fc44.aarch64 \
        'fex-emu-rootfs-fedora-44^20260410.n.0-1.fc44.noarch' \
        virglrenderer-1.3.0-1.fc44.aarch64 \
        mesa-dri-drivers-26.1.4-1.fc44.aarch64 \
        mesa-vulkan-drivers-26.1.4-1.fc44.aarch64 \
        gtk2-2.24.33-25.fc44.aarch64 \
        ibus-1.5.34-2.fc44.aarch64 \
        NetworkManager-1.56.1-2.fc44.aarch64 \
        openal-soft-1.24.2-6.fc44.aarch64 \
        libvdpau-1.5-11.fc44.aarch64 \
        libX11-devel-1.8.13-1.fc44.aarch64 \
        mesa-libGL-devel-26.1.4-1.fc44.aarch64 \
        steam-0-14.fc44.noarch \
        vulkan-loader-devel-1.4.341.0-1.fc44.aarch64 \
        xorg-x11-server-Xwayland-24.1.13-1.fc44.aarch64 >/dev/null
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

    steam-asahi-bootstrap = pkgs.writeShellScriptBin "steam-asahi-bootstrap" ''
      set -eu

      SOURCE=/home/uynx/nixos-config/steam-asahi
      IMAGE=localhost/steam-asahi:44
      CONTAINER=steam-asahi
      LABEL=io.uynx.steam-asahi.config

      if [ ! -f "$SOURCE/Containerfile" ] \
        || [ ! -f "$SOURCE/distrobox.ini" ] \
        || [ ! -f "$SOURCE/steam-guest-tune" ]; then
        ${pkgs.libnotify}/bin/notify-send \
          "Steam setup unavailable" \
          "Missing the versioned steam-asahi container files."
        exit 1
      fi

      CONFIG_HASH=$(
        ${pkgs.coreutils}/bin/sha256sum \
          "$SOURCE/Containerfile" "$SOURCE/distrobox.ini" \
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
          --file "$SOURCE/Containerfile" \
          "$SOURCE"
        REPLACE=1
      fi

      IMAGE_ID=$(
        ${pkgs.docker}/bin/docker image inspect \
          --format '{{.Id}}' "$IMAGE"
      )
      if ! ${pkgs.docker}/bin/docker container inspect "$CONTAINER" >/dev/null 2>&1; then
        ${pkgs.distrobox}/bin/distrobox assemble create \
          --file "$SOURCE/distrobox.ini"
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
          --file "$SOURCE/distrobox.ini"
      fi

      ${pkgs.distrobox}/bin/distrobox enter "$CONTAINER" -- rpm -q \
        muvm-0.6.0-3.fc44.aarch64 \
        fex-emu-2604-1.fc44.aarch64 \
        'fex-emu-rootfs-fedora-44^20260410.n.0-1.fc44.noarch' \
        virglrenderer-1.3.0-1.fc44.aarch64 \
        mesa-dri-drivers-26.1.4-1.fc44.aarch64 \
        mesa-vulkan-drivers-26.1.4-1.fc44.aarch64 \
        gtk2-2.24.33-25.fc44.aarch64 \
        ibus-1.5.34-2.fc44.aarch64 \
        NetworkManager-1.56.1-2.fc44.aarch64 \
        openal-soft-1.24.2-6.fc44.aarch64 \
        libvdpau-1.5-11.fc44.aarch64 \
        steam-0-14.fc44.noarch \
        xorg-x11-server-Xwayland-24.1.13-1.fc44.aarch64 >/dev/null
      ${pkgs.distrobox}/bin/distrobox enter "$CONTAINER" -- \
        test -x /opt/steam-arm64/steamrtarm64/steam
    '';

    # Steam, FEX, and muvm all live inside this dedicated container. Stopping the
    # container is the one reliable process boundary: it cannot leave a second
    # Steam client, FEX process, or Venus VM behind.
    steam-asahi-stop = pkgs.writeShellScriptBin "steam-asahi-stop" ''
      set -eu

      CONTAINER=steam-asahi
      RUNTIME_DIR=''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
      if [ "$(${pkgs.docker}/bin/docker container inspect \
        --format '{{.State.Running}}' "$CONTAINER" 2>/dev/null || true)" = true ]; then
        ${pkgs.docker}/bin/docker container stop --time 5 "$CONTAINER" >/dev/null
      fi

      # Launch watchers live outside the container. Stop them and remove their
      # locks so a fully stopped game cannot block its next launch.
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

      # These sockets are runtime-only. Removing them after a full container stop
      # prevents an interrupted muvm session from blocking the next clean launch.
      rm -rf \
        "$RUNTIME_DIR/krun" \
        "$RUNTIME_DIR/muvm.lock"
      rm -f \
        /home/uynx/.local/share/steam-asahi/home/.cache/steam-asahi/open-url.pipe
    '';

    # Wine and the ARM64 Steam client run inside muvm, where Distrobox's normal
    # xdg-open host forwarding cannot cross the VM boundary. Pass web URLs through
    # a FIFO in the shared Steam home and open them with the NixOS desktop handler.
    steam-guest-open = pkgs.writeShellScript "steam-guest-open" ''
      set -eu

      FIFO=/home/uynx/.local/share/steam-asahi/home/.cache/steam-asahi/open-url.pipe
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

    steam-compat-config = pkgs.writers.writePython3Bin "steam-compat-config" { } ''
      import re
      import sys
      from pathlib import Path

      config = Path(
          "/home/uynx/.local/share/steam-asahi/home/"
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

    # Forward commands from a short-lived native ARM64 guest to the running client.
    steam-asahi-remote = pkgs.writeShellScriptBin "steam-asahi-remote" ''
      set -eu

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

      STEAM_HOME=/home/uynx/.local/share/steam-asahi/home/.steam
      STEAM_BIN="$STEAM_HOME/root/steamrtarm64/steam"
      [ -p "$STEAM_HOME/steam.pipe" ] && [ -x "$STEAM_BIN" ]

      if [ "$TARGET" = 730 ]; then
        exec ${pkgs.distrobox}/bin/distrobox enter --no-workdir steam-asahi -- \
          /usr/bin/muvm -i -- "$STEAM_BIN" -applaunch "$TARGET" \
            -condebug +r_csgo_player_occlusion_query 0
      fi

      exec ${pkgs.distrobox}/bin/distrobox enter --no-workdir steam-asahi -- \
        /usr/bin/muvm -i -- "$STEAM_BIN" "$URL"
    '';

    steam-asahi-run = pkgs.writeShellScriptBin "steam-asahi-run" ''
      set -eu

      APP_ID=''${1:-}
      ${steam-asahi-bootstrap}/bin/steam-asahi-bootstrap
      ${steam-compat-config}/bin/steam-compat-config 32440 proton_10
      ${steam-compat-config}/bin/steam-compat-config 674940 box64_stickfight
      ${steam-compat-config}/bin/steam-compat-config 990080 proton_10

      STEAM_ROOT=/home/uynx/.local/share/steam-asahi/home/.local/share/Steam
      STEAM_HOME=/home/uynx/.local/share/steam-asahi/home/.steam
      STEAM_BIN="$STEAM_ROOT/steamrtarm64/steam"
      GUEST_BIN=/home/uynx/.local/share/steam-asahi/home/.local/bin
      URL_FIFO=/home/uynx/.local/share/steam-asahi/home/.cache/steam-asahi/open-url.pipe

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
      printf '%s\n' publicbeta >"$STEAM_ROOT/package/beta"
      ln -sfn "$STEAM_ROOT" "$STEAM_HOME/root"
      ln -sfn "$STEAM_ROOT/linuxarm64" "$STEAM_HOME/sdkarm64"
      chmod -R u+rwX "$STEAM_ROOT/steamrtarm64"

      if [ -n "$APP_ID" ]; then
        case "$APP_ID" in
          *[!0-9]*) exit 2 ;;
        esac
      fi

      set -- /usr/bin/muvm \
        -e "BROWSER=$GUEST_BIN/xdg-open" \
        --gpu-mode=venus
      if [ "$APP_ID" = 990080 ]; then
        # Hogwarts can otherwise let the Venus renderer grow beyond unified
        # memory headroom on this 16 GiB host.
        set -- "$@" --vram=4096
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
      ${pkgs.distrobox}/bin/distrobox enter --no-workdir steam-asahi -- "$@" || STATUS=$?
      ${steam-asahi-stop}/bin/steam-asahi-stop
      exit "$STATUS"
    '';

    # The native ARM64 client avoids FEX's current Steam UI restart/focus loop;
    # Windows games still use Proton and FEX inside the same Venus VM.
    steam-asahi = pkgs.writeShellScriptBin "steam-asahi" ''
      set -eu

      STEAM_ADDRESS=$(${H} clients -j 2>/dev/null | ${J} -r '
        [.[] | select(((.class // "") | ascii_downcase) == "steam") | .address][0] // empty
      ' 2>/dev/null || true)
      if [ -n "$STEAM_ADDRESS" ]; then
        exec ${H} dispatch focuswindow "address:$STEAM_ADDRESS"
      fi

      if [ "$(${pkgs.docker}/bin/docker container inspect \
        --format '{{.State.Running}}' steam-asahi 2>/dev/null || true)" = true ] && \
         [ -p /home/uynx/.local/share/steam-asahi/home/.steam/steam.pipe ]; then
        ${steam-asahi-remote}/bin/steam-asahi-remote ui || true
        for _ in $(${pkgs.coreutils}/bin/seq 1 50); do
          STEAM_ADDRESS=$(${H} clients -j 2>/dev/null | ${J} -r '
            [.[] | select(((.class // "") | ascii_downcase) == "steam") | .address][0] // empty
          ' 2>/dev/null || true)
          if [ -n "$STEAM_ADDRESS" ]; then
            exec ${H} dispatch focuswindow "address:$STEAM_ADDRESS"
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

      APP_ID=$1
      LOCK=$2
      if [ "$APP_ID" = 730 ]; then
        CLASS=cs2
      else
        CLASS=steam_app_$APP_ID
      fi
      cleanup() { rm -rf "$LOCK"; }
      trap cleanup EXIT
      printf '%s\n' "$$" >"$LOCK/pid"

      ADDRESS=
      for _ in $(${pkgs.coreutils}/bin/seq 1 600); do
        ADDRESS=$(${H} clients -j 2>/dev/null | ${J} -r --arg class "$CLASS" '
          [.[] | select(((.class // "") | ascii_downcase) == $class) | .address][0] // empty
        ' 2>/dev/null || true)
        [ -n "$ADDRESS" ] && break
        sleep 0.5
      done

      if [ -z "$ADDRESS" ]; then
        WINDOWS=$(${H} clients -j 2>/dev/null | ${J} -r '
          any(.[]; ((.class // "") | ascii_downcase) == "steam" or
                   ((.class // "") | ascii_downcase) == "cs2" or
                   ((.class // "") | test("^steam_app_[0-9]+$")))
        ' 2>/dev/null || echo true)
        [ "$WINDOWS" = true ] || ${steam-asahi-stop}/bin/steam-asahi-stop
        exit 0
      fi

      ${H} dispatch focuswindow "address:$ADDRESS" >/dev/null 2>&1 || true
      if [ "$APP_ID" != 674940 ]; then
        FULLSCREEN=$(${H} clients -j 2>/dev/null | ${J} -r --arg address "$ADDRESS" '
          [.[] | select(.address == $address) | .fullscreen][0] // 0
        ' 2>/dev/null || echo 0)
        if [ "$FULLSCREEN" = 0 ]; then
          ${H} dispatch fullscreen 0 >/dev/null 2>&1 || true
        fi
      fi

      while ${H} clients -j 2>/dev/null | ${J} -e --arg class "$CLASS" '
        any(.[]; ((.class // "") | ascii_downcase) == $class)
      ' >/dev/null 2>&1; do
        sleep 0.5
      done
      sleep 1

      WINDOWS=$(${H} clients -j 2>/dev/null | ${J} -r '
        any(.[]; ((.class // "") | ascii_downcase) == "steam" or
                 ((.class // "") | ascii_downcase) == "cs2" or
                 ((.class // "") | test("^steam_app_[0-9]+$")))
      ' 2>/dev/null || echo true)
      [ "$WINDOWS" = true ] || ${steam-asahi-stop}/bin/steam-asahi-stop
    '';

    # Match Wine's virtual desktop to the target monitor's exact logical size.
    steam-launch = pkgs.writeShellScriptBin "steam-launch" ''
      set -eu

      APP_ID=$1
      case "$APP_ID" in
        *[!0-9]*|"") exit 2 ;;
      esac

      if [ "$APP_ID" = 730 ]; then
        CLASS=cs2
      else
        CLASS=steam_app_$APP_ID
      fi
      GAME_ADDRESS=$(${H} clients -j 2>/dev/null | ${J} -r --arg class "$CLASS" '
        [.[] | select(((.class // "") | ascii_downcase) == $class) | .address][0] // empty
      ' 2>/dev/null || true)
      if [ -n "$GAME_ADDRESS" ]; then
        exec ${H} dispatch focuswindow "address:$GAME_ADDRESS"
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
        32440 | 990080)
          ${steam-compat-config}/bin/steam-compat-config "$APP_ID" proton_10
          ;;
        674940)
          ${steam-compat-config}/bin/steam-compat-config "$APP_ID" box64_stickfight
          ;;
      esac

      if ! RESOLUTION=$(${H} monitors -j 2>/dev/null | ${J} -er '
        (if any(.name == "HDMI-A-1") then .[] | select(.name == "HDMI-A-1") else .[] | select(.focused) end)
        | select(.width > 0 and .height > 0 and .scale > 0)
        | "\((.width / .scale) | floor)x\((.height / .scale) | floor)"
      ' 2>/dev/null); then
        ${pkgs.libnotify}/bin/notify-send \
          "Steam game not launched" \
          "Could not read the target monitor resolution from Hyprland."
        exit 1
      fi
      WIDTH=''${RESOLUTION%x*}
      HEIGHT=''${RESOLUTION#*x}

      if [ "$APP_ID" = 730 ]; then
        CS2_VIDEO=/home/uynx/.local/share/steam-asahi/home/.local/share/Steam/userdata/483670283/730/local/cfg/cs2_video.txt
        if ${H} monitors -j 2>/dev/null | ${J} -e 'any(.name == "HDMI-A-1")' >/dev/null; then
          CS2_MONITOR=1
        else
          CS2_MONITOR=0
        fi
        CS2_REFRESH=$(${H} monitors -j 2>/dev/null | ${J} -r '
          (if any(.name == "HDMI-A-1") then .[] | select(.name == "HDMI-A-1") else .[] | select(.focused) end)
          | .refreshRate | round
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

      COMPAT="/home/uynx/.local/share/steam-asahi/home/.local/share/Steam/steamapps/compatdata"
      PREFIX="$COMPAT/''${APP_ID}/pfx"
      REG_FILE="$PREFIX/user.reg"
      if [ "$APP_ID" = 3540 ] && [ -f "$REG_FILE" ]; then
        STAMP=$(date +%s)
        # Older versions of this helper let printf consume registry backslashes.
        # Remove those malformed sections before writing the real Wine keys.
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
        --format '{{.State.Running}}' steam-asahi 2>/dev/null || true)
      if [ "$CONTAINER_RUNNING" = true ]; then
        for _ in $(${pkgs.coreutils}/bin/seq 1 100); do
          [ -p /home/uynx/.local/share/steam-asahi/home/.steam/steam.pipe ] && break
          sleep 0.1
        done
        if [ -p /home/uynx/.local/share/steam-asahi/home/.steam/steam.pipe ]; then
          ${steam-asahi-remote}/bin/steam-asahi-remote "$APP_ID"
          exit 0
        fi

        STEAM_ADDRESS=$(${H} clients -j 2>/dev/null | ${J} -r '
          [.[] | select(((.class // "") | ascii_downcase) == "steam") | .address][0] // empty
        ' 2>/dev/null || true)
        if [ -n "$STEAM_ADDRESS" ]; then
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

      STEAM_ROOT=/home/uynx/.local/share/steam-asahi/home/.local/share/Steam
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

    steam-fuzzel = pkgs.writeShellScriptBin "steam-fuzzel" ''
      ${steam-game-entries}/bin/steam-game-entries
      exec ${pkgs.fuzzel}/bin/fuzzel "$@"
    '';

    hypr-close-active = pkgs.writeShellScriptBin "hypr-close-active" ''
      set -eu

      ACTIVE=$(${H} activewindow -j 2>/dev/null || echo '{}')
      CLASS=$(printf '%s' "$ACTIVE" | ${J} -r '.class // ""' 2>/dev/null || true)
      PID=$(printf '%s' "$ACTIVE" | ${J} -r '.pid // 0' 2>/dev/null || true)
      case "$CLASS" in
        steam|Steam|steam_app_[0-9]*|cs2)
          # The VM is the reliable process boundary. Closing only the XWayland
          # window can leave Proton and the game running headless.
          exec ${steam-asahi-stop}/bin/steam-asahi-stop
          ;;
        antigravity|Antigravity)
          # Electron app leaves headless process + SingletonSocket if only window closed.
          # Kill the main process tree directly so it exits fully and cleans up.
          if [ "$PID" -gt 0 ] 2>/dev/null; then
            kill -15 "$PID" 2>/dev/null || kill -9 "$PID" 2>/dev/null || true
          fi
          ${pkgs.procps}/bin/pkill -f "/.local/share/antigravity/antigravity" 2>/dev/null || true
          ;;
        *)
          exec ${H} dispatch closewindow active
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
        steam-fuzzel
        distrobox
        dive
        hypr-close-active
      ];

      home.file.".local/bin/hypr-close-active".source =
        "${hypr-close-active}/bin/hypr-close-active";

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
        ".local/share/steam-asahi/home/.local/share/Steam/steamapps/common/Counter-Strike Global Offensive/game/csgo/cfg/autoexec.cfg" =
          {
            force = true;
            text = ''
              // Venus can lose CS2's player-occlusion query pool during match load.
              r_csgo_player_occlusion_query 0
            '';
          };
          ".local/share/steam-asahi/home/.local/share/Steam/compatibilitytools.d/Box64-StickFight/compatibilitytool.vdf".text =
            ''
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
          ".local/share/steam-asahi/home/.local/share/Steam/compatibilitytools.d/Box64-StickFight/toolmanifest.vdf".text =
            ''
              "manifest"
              {
                "commandline" "/proton run"
                "commandline_getnativepath" "/proton getnativepath"
                "commandline_getcompatpath" "/proton getcompatpath"
                "commandline_waitforexitandrun" "/proton waitforexitandrun"
              }
            '';
          ".local/share/steam-asahi/home/.local/share/Steam/compatibilitytools.d/Box64-StickFight/proton" = {
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
              PROTON=/home/uynx/.local/share/steam-asahi/home/.local/share/Steam/steamapps/common/Proton\ 10.0/files
              export WINEPREFIX=/home/uynx/.local/share/steam-asahi/home/.local/share/Steam/steamapps/compatdata/674940/pfx
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
