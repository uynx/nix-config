{ self, ... }:
{
  flake.homeModules.waydroid =
    { pkgs, lib, ... }:
    let
      update-android = self.lib.mkUpdater pkgs {
        name = "update-android";
        text = ''
          file=$HOME/nix-config/modules/hosts/waydroid/pins.json
          ota=https://ota.waydro.id

          pin() {
            r=$(fetch "$1" | jq -e '.response[0]')
            jq -n --argjson r "$r" --arg h "$(nix hash convert --hash-algo sha256 --to sri "$(echo "$r" | jq -r .id)")" \
              '{ name: $r.filename, url: $r.url, hash: $h }'
          }
          system=$(pin $ota/system/lineage/waydroid_arm64_only/GAPPS.json)
          vendor=$(pin $ota/vendor/waydroid_arm64_only/MAINLINE.json)

          current=$(jq -r .system.name "$file" 2>/dev/null || echo none)
          latest=$(echo "$system" | jq -r .name)
          jq_write "$file" -n --argjson s "$system" --argjson v "$vendor" '{ system: $s, vendor: $v }'
          report android "$current" "$latest"
        '';
      };
      lid-saver = pkgs.writeShellApplication {
        name = "lid-saver";
        runtimeInputs = with pkgs; [
          jq
          socat
        ];
        text = builtins.readFile ./lid-saver.sh;
      };
    in
    {
      config = lib.mkIf pkgs.stdenv.hostPlatform.isAarch64 {
        home.packages = [
          update-android
          lid-saver
        ];

        shellHooks.update = [ "update-android" ];

        xdg.desktopEntries.android = {
          name = "Android";
          exec = "fish -c android";
          icon = "android";
          terminal = false;
        };
        xdg.dataFile."icons/hicolor/scalable/apps/android.svg".source = ./android.svg;

        programs.fish.functions.android.body = ''
          set -l state ~/.local/share/waydroid-vm
          set -l jq ${lib.getExe pkgs.jq}

          mkdir -p $state
          if not ${pkgs.util-linux}/bin/flock -n $state/launch.lock true
              set -l id (niri msg -j windows | $jq -r '[.[] | select(.app_id == "qemu")][0].id // empty')
              test -n "$id"; and niri msg action focus-window --id $id
              echo "Android is already running or starting."
              return 0
          end

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

          cd $state
          or return 1

          set -x QEMU_OPTS "-device virtio-gpu-gl-pci,xres=$size[1],yres=$size[2] -display gtk,gl=on,show-menubar=off -full-screen"
          ${pkgs.util-linux}/bin/flock -n $state/launch.lock nix run ~/nix-config#nixosConfigurations.waydroid.config.system.build.vm
        '';
      };
    };
}
