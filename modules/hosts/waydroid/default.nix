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

          boot.kernelPatches = [
            {
              name = "iptables-legacy-for-android-netd";
              patch = null;
              structuredExtraConfig = with lib.kernel; {
                NETFILTER_XTABLES_LEGACY = yes;
                IP_NF_IPTABLES_LEGACY = module;
                IP6_NF_IPTABLES_LEGACY = module;
              };
            }
          ];

          boot.kernelModules = [
            "ip_tables"
            "iptable_filter"
            "iptable_nat"
            "iptable_mangle"
            "iptable_raw"
            "ip6_tables"
          ];

          virtualisation = {
            waydroid.enable = true;
            memorySize = 8192;
            cores = 4;
            diskSize = 16384;
            graphics = true;

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
              [ -d /var/lib/waydroid/images ] || ${pkgs.waydroid}/bin/waydroid init -s GAPPS
            '';
          };

          systemd.services.waydroid-props = {
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

          services.cage = {
            enable = true;
            user = "android";
            program = "${launch}/bin/launch-waydroid";
          };

          systemd.services.cage-tty1.environment.WLR_NO_HARDWARE_CURSORS = "1";

          systemd.services.cage-tty1.serviceConfig = {
            Restart = "on-failure";
            RestartSec = 5;
          };

          hardware.graphics.enable = true;

          networking.nftables.enable = true;

          networking.firewall.enable = false;
          environment.systemPackages = [ pkgs.dnsmasq ];

          services.openssh = {
            enable = true;
            settings.PasswordAuthentication = true;
          };

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
