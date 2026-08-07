{ inputs, ... }:
{
  # Waydroid runs Android on the *host* kernel and Asahi's is 16 KiB-page
  # (waydroid#577, wontfix); stock nixpkgs aarch64 is 4 KiB with binder, so a
  # guest is the whole fix. Launch with the `android` fish function.
  flake.nixosConfigurations.waydroid = inputs.nixpkgs.lib.nixosSystem {
    system = "aarch64-linux";
    modules = [
      (
        {
          modulesPath,
          pkgs,
          lib,
          ...
        }:
        let
          # Wait on the container unit, not `status | grep RUNNING`: the session
          # only reaches RUNNING because show-full-ui starts it, so that deadlocks.
          launch = pkgs.writeShellScriptBin "launch-waydroid" ''
            until systemctl is-active --quiet waydroid-container; do
              sleep 2
            done

            # Doze stalls WhatsApp's companion sync; no battery here to save.
            {
              until ${pkgs.waydroid}/bin/waydroid status 2>/dev/null \
                | grep -q 'Session:[[:space:]]*RUNNING'; do
                sleep 2
              done
              sudo ${pkgs.waydroid}/bin/waydroid shell -- dumpsys deviceidle disable
              sudo ${pkgs.waydroid}/bin/waydroid shell -- svc power stayon true

              # Do not re-add a TCP MSS clamp. Under passt the route MTU is
              # 65520, so it clamps MSS *up*; removing it restored 5.5 MB/s.
            } &

            exec ${pkgs.waydroid}/bin/waydroid show-full-ui
          '';
        in
        {
          imports = [ "${modulesPath}/virtualisation/qemu-vm.nix" ];

          # netd builds per-app networking on legacy iptables chains that
          # nixpkgs kernels omit, so apps half-work while a root shell (which
          # bypasses the chains) still measures healthy. Costs a kernel rebuild.
          boot.kernelPatches = [
            {
              name = "iptables-legacy-for-android-netd";
              patch = null;
              # IP_NF_* are module-or-off; asking for `yes` loops the generator.
              structuredExtraConfig = with lib.kernel; {
                NETFILTER_XTABLES_LEGACY = yes;
                IP_NF_IPTABLES_LEGACY = module;
                IP6_NF_IPTABLES_LEGACY = module;
              };
            }
          ];

          # Load up front: netd runs early and errors uselessly on a missing table.
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
            memorySize = 8192; # 4096 froze on heavy pages; host has 15 GB
            cores = 4;
            diskSize = 16384; # Android system image plus apps
            graphics = true;

            # passt, not qemu's SLIRP, which chokes on the parallel connections
            # apps use. Replaces the list wholesale, so forwardPorts no longer
            # applies; mkForce because qemu-vm.nix defines rather than defaults it.
            qemu.networkingOptions = lib.mkForce [
              "-netdev passt,id=net0,path=${pkgs.passt}/bin/passt,tcp-ports=2222:22"
              "-device virtio-net-pci,netdev=net0"
            ];
            qemu.options = [
              # No GPU/display device on purpose: its size must match the
              # monitor the window lands on in *logical* pixels or clicks land
              # off target, so the `android` fish function passes both through
              # QEMU_OPTS. QMP is how pointer events get injected at exact
              # coordinates to check what Android actually receives.
              "-qmp unix:/tmp/waydroid-qmp.sock,server=on,wait=off"

              # hda-duplex is the point: a call needs mic in, not just audio out.
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
            # GAPPS, not VANILLA: WhatsApp needs Play Services for registration
            # and for the push channel incoming calls ring on.
            script = ''
              [ -d /var/lib/waydroid/images ] || ${pkgs.waydroid}/bin/waydroid init -s GAPPS
            '';
          };

          # Earlier attempts wrote resolution overrides into the disk image;
          # they must not survive, since the size now follows the Wayland
          # output. mainkeys=1 goes too — it only cost the navigation bar.
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

          # The VM window is the Android screen; there is no desktop behind it.
          services.cage = {
            enable = true;
            user = "android";
            program = "${launch}/bin/launch-waydroid";
          };

          # Through virtio-gpu the hardware cursor plane renders flipped with
          # its hotspot left at the top-left, so every button had to be clicked
          # from below. Draw the cursor into the framebuffer instead.
          systemd.services.cage-tty1.environment.WLR_NO_HARDWARE_CURSORS = "1";

          # The container comes up well after the compositor, and a dead
          # compositor means a blank window with no way back.
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

          # Makes the NixOS module pick waydroid-nftables. The default
          # waydroid-net.sh shells out to legacy iptables, which nixpkgs kernels
          # no longer ship, so every table creation fails and no session starts.
          networking.nftables.enable = true;

          # Strict reverse-path filtering drops the container's bridged and
          # NATed traffic — the classic "ping and DNS fine, apps load nothing"
          # failure. Only passt's one forwarded port reaches this guest anyway.
          networking.firewall.enable = false;
          # waydroid-net.sh also runs dnsmasq for the container's DHCP.
          environment.systemPackages = [ pkgs.dnsmasq ];

          services.openssh = {
            enable = true;
            settings.PasswordAuthentication = true;
          };

          # Throwaway local guest, reachable only from this machine's qemu window.
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
