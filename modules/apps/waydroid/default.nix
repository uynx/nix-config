{
  flake.homeModules.waydroid =
    { pkgs, lib, ... }:
    let
      update-android = pkgs.writers.writeDashBin "update-android" ''
        set -eu
        export PATH=${
          lib.makeBinPath (
            with pkgs;
            [
              coreutils
              curl
              jq
              nix
            ]
          )
        }

        file=$HOME/nix-config/modules/hosts/waydroid/pins.json
        ota=https://ota.waydro.id

        pin() {
          r=$(curl -fsSL --retry 3 --retry-all-errors --connect-timeout 10 --max-time 60 "$1" | jq -e '.response[0]')
          jq -n --argjson r "$r" --arg h "$(nix hash convert --hash-algo sha256 --to sri "$(echo "$r" | jq -r .id)")" \
            '{ name: $r.filename, url: $r.url, hash: $h }'
        }
        system=$(pin $ota/system/lineage/waydroid_arm64/GAPPS.json)
        vendor=$(pin $ota/vendor/waydroid_arm64/MAINLINE.json)

        current=$(jq -r .system.name "$file" 2>/dev/null || echo none)
        latest=$(echo "$system" | jq -r .name)
        tmp=$(mktemp)
        jq -n --argjson s "$system" --argjson v "$vendor" '{ system: $s, vendor: $v }' >"$tmp"
        mv "$tmp" "$file"

        if [ "$current" = "$latest" ]; then
          printf '%-12s %s (up to date)\n' android "$current"
        else
          printf '%-12s %s -> %s\n' android "$current" "$latest"
        fi
      '';
    in
    {
      home.packages = [ update-android ];

      shellHooks.update = [ "update-android" ];

      xdg.desktopEntries.android = {
        name = "Android";
        exec = "fish -c android";
        icon = "phone";
        terminal = false;
      };

      programs.fish.functions.android.body = ''
        set -l state ~/.local/share/waydroid-vm
        set -l jq ${lib.getExe pkgs.jq}

        set -l output
        if niri msg -j outputs | $jq -e 'has("HDMI-A-1")' >/dev/null 2>&1
            set output (niri msg -j outputs | $jq -c '."HDMI-A-1"')
        else
            set output (niri msg -j focused-output)
        end

        set -l size (printf '%s' "$output" | $jq -er '.logical | "\(.width) \(.height)"' | string split ' ')
        if test (count $size) -ne 2
            echo "Could not read the monitor size from niri."
            return 1
        end

        mkdir -p $state
        cd $state
        or return 1

        set -x QEMU_OPTS "-device virtio-gpu-gl-pci,xres=$size[1],yres=$size[2] -display gtk,gl=on,show-menubar=off -full-screen"
        nix run ~/nix-config#nixosConfigurations.waydroid.config.system.build.vm
      '';
    };
}
