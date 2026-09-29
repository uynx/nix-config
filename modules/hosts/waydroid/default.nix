{ self, inputs, ... }:
{
  flake.nixosConfigurations.waydroid = inputs.nixpkgs.lib.nixosSystem {
    system = "aarch64-linux";
    modules = [
      self.nixosModules.audio
      (
        {
          modulesPath,
          pkgs,
          lib,
          ...
        }:
        let
          pins = lib.importJSON ./pins.json;
          image =
            part:
            pkgs.runCommand "waydroid-${part}.img" { } ''
              ${lib.getExe pkgs.unzip} -p ${pkgs.fetchurl pins.${part}} ${part}.img >$out
            '';

          launch = pkgs.writeShellScriptBin "launch-waydroid" ''
            until systemctl is-active --quiet waydroid-container; do
              sleep 2
            done

            {
              until ${pkgs.waydroid}/bin/waydroid status 2>/dev/null \
                | grep -q 'Session:[[:space:]]*RUNNING'; do
                sleep 2
              done
              sudo ${pkgs.waydroid}/bin/waydroid shell -- dumpsys deviceidle disable
              sudo ${pkgs.waydroid}/bin/waydroid shell -- svc power stayon true

            } &

            exec ${pkgs.waydroid}/bin/waydroid show-full-ui
          '';
        in
        {
          imports = [ "${modulesPath}/virtualisation/qemu-vm.nix" ];

          boot.kernelPackages = pkgs.linuxPackages_latest;
          boot.binfmt = {
            emulatedSystems = [ "armv7l-linux" ];
            preferStaticEmulators = true;
          };

          virtualisation = {
            waydroid.enable = true;
            memorySize = 8192;
            cores = 4;
            diskSize = 16384;
            graphics = true;
            qemu.enableSharedMemory = true;

            qemu.networkingOptions = lib.mkForce [
              "-netdev passt,id=net0,path=${pkgs.passt}/bin/passt,tcp-ports=2222:22"
              "-device virtio-net-pci,netdev=net0"
            ];
            qemu.options = [
              "-qmp unix:/tmp/waydroid-qmp.sock,server=on,wait=off"

              "-audiodev pipewire,id=snd0"
              "-device intel-hda"
              "-device hda-duplex,audiodev=snd0"
            ];
          };

          systemd.services = {
            waydroid-image = {
              description = "Point Waydroid at the pinned Android images";
              wantedBy = [ "multi-user.target" ];
              before = [ "waydroid-container.service" ];
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
              };
              script = ''
                grep -qx 'images_path = /etc/waydroid-extra/images' /var/lib/waydroid/waydroid.cfg 2>/dev/null \
                  || ${pkgs.waydroid}/bin/waydroid init -f
                rm -rf /var/lib/waydroid/images
              '';
            };

            waydroid-props = {
              description = "Strip stale Waydroid display overrides before the container starts";
              wantedBy = [ "multi-user.target" ];
              after = [ "waydroid-image.service" ];
              before = [ "waydroid-container.service" ];
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
              };
              script = ''
                f=/var/lib/waydroid/waydroid_base.prop
                [ -e "$f" ] || exit 0
                ${pkgs.gnused}/bin/sed -i \
                  -e '/^qemu\.hw\.mainkeys=/d' \
                  -e '/^persist\.waydroid\.width=/d' \
                  -e '/^persist\.waydroid\.height=/d' "$f"
              '';
            };

            cage-tty1 = {
              environment.WLR_NO_HARDWARE_CURSORS = "1";
              serviceConfig = {
                Restart = "on-failure";
                RestartSec = 5;
              };
            };
          };

          services = {
            cage = {
              enable = true;
              user = "android";
              program = "${launch}/bin/launch-waydroid";
            };

            openssh = {
              enable = true;
              settings.PasswordAuthentication = true;
            };

            getty.autologinUser = "root";
          };

          networking = {
            nftables.enable = true;
            firewall.enable = false;
            hostName = "waydroid";
          };

          hardware.graphics.enable = true;
          environment.etc = lib.genAttrs [ "system" "vendor" ] (part: {
            target = "waydroid-extra/images/${part}.img";
            source = image part;
          });
          environment.systemPackages = [ pkgs.dnsmasq ];

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

          system.stateVersion = "26.05";
        }
      )
    ];
  };
}
