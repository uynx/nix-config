{
  # The launcher for the guest defined in `modules/hosts/waydroid/` — a program
  # on this machine, not part of that machine, hence its own app dir. Lived in
  # the fish wrapper until it turned out every host got a command that only
  # works inside a niri session.
  flake.homeModules.waydroid =
    { pkgs, lib, ... }:
    {
      # niri stays a bare command: perSystem's nixpkgs has no libdisplay-info
      # overlay, and referencing it by store path here would make any host
      # evaluating this build its own unpatched copy.
      programs.fish.functions.android.body = ''
        # Sized to the monitor it opens on. Must be the *logical* size, used as
        # niri reports it — do not divide by the scale again. A mismatch does not
        # letterbox the picture, it scales every click, since qemu maps pointer
        # position by proportion.
        set -l state ~/.local/share/waydroid-vm
        set -l jq ${lib.getExe pkgs.jq}

        # The external monitor if attached, otherwise whichever output has focus.
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

        # The disk image lives in the working directory; running this anywhere
        # else starts a blank Android and re-downloads 1.6 GB.
        mkdir -p $state
        cd $state
        or return 1

        set -x QEMU_OPTS "-device virtio-gpu-gl-pci,xres=$size[1],yres=$size[2] -display gtk,gl=on,show-menubar=off -full-screen"
        nix run ~/nix-config#nixosConfigurations.waydroid.config.system.build.vm
      '';
    };
}
