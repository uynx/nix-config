{
  flake.homeModules.waydroid =
    { pkgs, lib, ... }:
    {
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
