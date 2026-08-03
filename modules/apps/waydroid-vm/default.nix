{ inputs, ... }:
{
  # A guest whose only job is to be a 4 KiB-page machine: Waydroid runs Android
  # on the *host* kernel, and Asahi's is 16 KiB (waydroid#577, wontfix). Stock
  # nixpkgs aarch64 is already 4 KiB with binder on, so that is the whole fix.
  # Google Play Services never worked here and is not being pursued.
  #   nix run .#nixosConfigurations.waydroid.config.system.build.vm
  flake.nixosConfigurations.waydroid = inputs.nixpkgs.lib.nixosSystem {
    system = "aarch64-linux";
    modules = [
      (
        { modulesPath, pkgs, lib, ... }:
        let
          # Wait on the container unit, not "status | grep RUNNING": the session
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

              # Do not re-add a TCP MSS clamp here. It existed for SLIRP; under
              # passt the route MTU is 65520, so it clamped MSS *up* and killed
              # throughput. Removing it restored 5.5 MB/s.
            } &

            exec ${pkgs.waydroid}/bin/waydroid show-full-ui
          '';
        in
        {
          imports = [ "${modulesPath}/virtualisation/qemu-vm.nix" ];

          # netd builds per-app networking on legacy iptables chains, which
          # nixpkgs kernels omit — so netd installs none, apps half-work, and a
          # root shell (which bypasses the chains) still measures healthy. Costs
          # a full kernel rebuild; there is no lighter fix.
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
            # 4096 froze heavy pages: Chromium is a process per renderer. Host has 15 GB.
            memorySize = 8192;
            cores = 4;
            diskSize = 16384; # Android system image plus apps
            graphics = true;

            # passt instead of qemu's SLIRP, which is fine for one transfer at a
            # time (why the network kept measuring healthy) but poor at the many
            # parallel connections apps use. Replaces the list wholesale, so
            # forwardPorts no longer applies and ssh moves to tcp-ports; mkForce
            # because qemu-vm.nix defines rather than defaults it.
            qemu.networkingOptions = lib.mkForce [
              "-netdev passt,id=net0,path=${pkgs.passt}/bin/passt,tcp-ports=2222:22"
              "-device virtio-net-pci,netdev=net0"
            ];
            qemu.options = [
              # No GPU/display device here on purpose: aarch64 "virt" has no
              # default adapter, but the size must match the monitor the window
              # lands on in *logical* pixels or clicks land off target. Only
              # knowable at launch, so the `android` fish function passes both
              # through QEMU_OPTS.
              #
              # QMP allows injecting pointer events at exact coordinates, the
              # only way to compare what Android receives against what was sent.
              "-qmp unix:/tmp/waydroid-qmp.sock,server=on,wait=off"

              # hda-duplex is the point: a call needs mic in, not just audio out.
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
            # GAPPS rather than VANILLA: WhatsApp leans on Play Services for
            # parts of registration and for push, and its sync failures are
            # reported almost exclusively against de-Googled builds. Play also
            # supplies the push channel incoming calls need to ring at all.
            script = ''
              [ -d /var/lib/waydroid/images ] || ${pkgs.waydroid}/bin/waydroid init -s GAPPS
            '';
          };

          # Android's resolution must follow the Wayland output rather than be
          # pinned: the output size now depends on which monitor the window
          # opens on. These keys were written into the disk image by earlier
          # attempts and would override that, so strip them every boot.
          # qemu.hw.mainkeys=1 is stripped too — hiding the navigation bar did
          # not fix the clicks and only cost the Back/Home/Recents buttons.
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

          # Draw the cursor into the framebuffer instead of using the GPU's
          # cursor plane. Through virtio-gpu that plane renders the sprite
          # vertically flipped while its hotspot stays at the top-left, so the
          # arrow you see sits about one cursor-height below the point that
          # actually clicks — every button had to be clicked from below. The
          # geometry was never wrong, which is why matching resolutions never
          # helped.
          systemd.services.cage-tty1.environment.WLR_NO_HARDWARE_CURSORS = "1";

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

          # NixOS turns on strict reverse-path filtering
          # (networking.firewall.checkReversePath), which drops packets whose
          # return route does not point back out the interface they arrived
          # on. That is the most commonly reported cause of Waydroid's
          # signature failure — ping and DNS fine, apps unable to load
          # anything — because the container's traffic is bridged and NATed.
          # Nothing here needs a firewall: the guest is reachable only through
          # the single port passt forwards, so drop the whole thing rather
          # than tune one sysctl.
          networking.firewall.enable = false;
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
