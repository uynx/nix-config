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
        { modulesPath, pkgs, lib, ... }:
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

            # Android doze suspends background network, which stalls WhatsApp's
            # initial companion-mode sync partway through. There is no battery
            # here to save, so turn it off every boot rather than by hand.
            {
              until ${pkgs.waydroid}/bin/waydroid status 2>/dev/null \
                | grep -q 'Session:[[:space:]]*RUNNING'; do
                sleep 2
              done
              sudo ${pkgs.waydroid}/bin/waydroid shell -- dumpsys deviceidle disable
              sudo ${pkgs.waydroid}/bin/waydroid shell -- svc power stayon true

              # Clamp TCP MSS to the real path MTU. Waydroid's iptables path
              # does this; its nftables path does not, and the guest reaches
              # the outside through qemu's user-mode networking, which cannot
              # carry full-size segments. The result is the documented
              # waydroid#105 symptom: DNS and ping fine, handshakes fine, but
              # any sustained transfer stalls — pages half-load and WhatsApp's
              # sync never finishes. The table only exists once the container
              # has started, so this cannot go in networking.nftables.ruleset.
              sudo ${pkgs.nftables}/bin/nft add rule inet lxc forward \
                tcp flags syn tcp option maxseg size set rt mtu || true
            } &

            exec ${pkgs.waydroid}/bin/waydroid show-full-ui
          '';
        in
        {
          imports = [ "${modulesPath}/virtualisation/qemu-vm.nix" ];

          # Android's netd builds all of its per-app networking on iptables
          # chains (bw_* for bandwidth, fw_* for the per-app firewall). nixpkgs
          # ships kernels with NETFILTER_XTABLES_LEGACY off, so those tables do
          # not exist, netd installs zero chains, and every app's traffic
          # half-works while a root shell — which bypasses the chains — looks
          # perfectly healthy. That mismatch is why the network measured fine
          # from ssh while the browser and WhatsApp stalled.
          #
          # This forces a full kernel rebuild, which is slow but is the only
          # real fix: waydroid#105's usual workaround needs these same tables.
          boot.kernelPatches = [
            {
              name = "iptables-legacy-for-android-netd";
              patch = null;
              # The IP_NF_* ones only offer module-or-off, so asking for `yes`
              # makes the config generator loop and fail.
              structuredExtraConfig = with lib.kernel; {
                NETFILTER_XTABLES_LEGACY = yes;
                IP_NF_IPTABLES_LEGACY = module;
                IP6_NF_IPTABLES_LEGACY = module;
              };
            }
          ];

          # Load them up front rather than relying on the container to do it:
          # netd runs early and gives no useful error when a table is missing.
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
              # No display device here on purpose. The screen size has to match
              # the monitor the window actually lands on, in *logical* pixels,
              # or every pointer coordinate is scaled and clicks land off
              # target. That is only knowable at launch, so the `android` fish
              # function computes it and passes the GPU and display through
              # QEMU_OPTS. This is the same rule the Steam launcher follows for
              # Wine's virtual desktop.
              # Lets pointer events be injected at exact coordinates, which is
              # the only way to measure what Android actually receives versus
              # what was sent. Guessing at the mapping wasted several reboots.
              "-qmp unix:/tmp/waydroid-qmp.sock,server=on,wait=off"

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
