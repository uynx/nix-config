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
          # first boot it also waits behind the image download.
          #
          # Wait on the *container unit*, not on "waydroid status | grep
          # RUNNING": the session only reaches RUNNING because show-full-ui
          # starts it, so waiting for RUNNING first deadlocks.
          launch = pkgs.writeShellScriptBin "launch-waydroid" ''
            until systemctl is-active --quiet waydroid-container; do
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
            # The qemu window shows the Android screen but nothing about the
            # machine behind it, so keep a way in: ssh -p 2222 android@localhost
            forwardPorts = [
              {
                from = "host";
                host.port = 2222;
                guest.port = 22;
              }
            ];
            qemu.options = [
              # qemu's aarch64 "virt" machine has no default display adapter and
              # the NixOS VM module does not add one, so without this the guest
              # has no /dev/dri at all and every compositor dies on startup.
              "-device virtio-gpu-gl-pci"
              # show-menubar=off because clicks landed consistently ~31px above
              # where they were pressed, and 31px is about the height of gtk's
              # menubar — the guest's mode was 1426x1035 while Android sized
              # itself 1426x1004. Removing the bar is the fix to try; forcing
              # Android's size to match instead treated the symptom.
              "-display gtk,gl=on,show-menubar=off"

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

          # Waydroid's container comes up well after the compositor does, and a
          # dead compositor means a blank window with no way back.
          systemd.services.cage-tty1.serviceConfig = {
            Restart = "on-failure";
            RestartSec = 5;
          };

          services.pipewire = {
            enable = true;
            alsa.enable = true;
            pulse.enable = true;
          };

          hardware.graphics.enable = true;

          # waydroid-net.sh sets up the container's bridge. Its default build
          # shells out to legacy iptables, and nixpkgs kernels no longer ship
          # the ip_tables module at all, so every table creation fails and the
          # Android session never starts. Turning nftables on makes the NixOS
          # module pick pkgs.waydroid-nftables, which speaks nft instead.
          networking.nftables.enable = true;
          # The same script runs dnsmasq for the container's DHCP.
          environment.systemPackages = [ pkgs.dnsmasq ];

          services.openssh = {
            enable = true;
            settings.PasswordAuthentication = true;
          };

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
