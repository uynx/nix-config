{ inputs, ... }:
{
  # A guest whose only job is to be a 4 KiB-page machine.
  #
  # Waydroid runs Android as an LXC container on the *host* kernel, and this
  # laptop's Asahi kernel is 16 KiB pages, which Android cannot use — see
  # waydroid#577, closed as not planned. Stock nixpkgs aarch64 kernels default
  # to 4 KiB and already set ANDROID_BINDER_IPC + ANDROID_BINDERFS, so simply
  # not using the Asahi kernel is the entire fix. No custom kernel, no DKMS.
  #
  # Run it with:
  #   nix run .#nixosConfigurations.waydroid.config.system.build.vm
  # The qcow2 it creates in $PWD is where the Android image and apps live.
  flake.nixosConfigurations.waydroid = inputs.nixpkgs.lib.nixosSystem {
    system = "aarch64-linux";
    modules = [
      (
        { modulesPath, pkgs, ... }:
        let
          # show-full-ui races the container service on a cold boot, and on
          # first boot it also waits behind a ~2 GB image download.
          launch = pkgs.writeShellScriptBin "launch-waydroid" ''
            until ${pkgs.waydroid}/bin/waydroid status 2>/dev/null | grep -q RUNNING; do
              sleep 2
            done
            exec ${pkgs.waydroid}/bin/waydroid show-full-ui
          '';
        in
        {
          imports = [ "${modulesPath}/virtualisation/qemu-vm.nix" ];

          virtualisation = {
            waydroid.enable = true;
            memorySize = 4096;
            cores = 4;
            diskSize = 16384; # Android system image plus apps
            graphics = true;
            qemu.options = [
              # hda-duplex is the whole point: a call needs mic in, not just
              # audio out. Everything else here is incidental.
              "-audiodev pipewire,id=snd0"
              "-device intel-hda"
              "-device hda-duplex,audiodev=snd0"
            ];
          };

          # Pulls the LineageOS image once, before anything tries to show it.
          systemd.services.waydroid-image = {
            description = "Fetch the Waydroid Android image on first boot";
            wantedBy = [ "multi-user.target" ];
            before = [ "waydroid-container.service" ];
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
            };
            script = ''
              [ -d /var/lib/waydroid/images ] || ${pkgs.waydroid}/bin/waydroid init
            '';
          };

          # The VM window is the Android screen; there is no desktop behind it.
          services.cage = {
            enable = true;
            user = "android";
            program = "${launch}/bin/launch-waydroid";
          };

          services.pipewire = {
            enable = true;
            alsa.enable = true;
            pulse.enable = true;
          };

          hardware.graphics.enable = true;

          # Throwaway local guest, reachable only from this machine's qemu
          # window. Not worth a password prompt in front of a phone call.
          users.users.android = {
            isNormalUser = true;
            password = "android";
            extraGroups = [
              "wheel"
              "video"
              "audio"
              "render"
            ];
          };
          security.sudo.wheelNeedsPassword = false;
          services.getty.autologinUser = "root";

          networking.hostName = "waydroid";
          system.stateVersion = "26.05";
        }
      )
    ];
  };
}
