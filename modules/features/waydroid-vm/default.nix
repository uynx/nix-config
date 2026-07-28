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

              # Android caches the device name in its settings database on
              # first boot, so it keeps reporting "linux,dummy-virt" long
              # after the properties say Pixel 5. This lives in /data, which
              # no property can override.
              sudo ${pkgs.waydroid}/bin/waydroid shell -- \
                settings put global device_name "Pixel 5" || true

              # There used to be a TCP MSS clamp here, working around qemu's
              # user-mode networking being unable to carry full-size segments
              # (waydroid#105). passt replaced that uplink and does not need
              # it — worse, the clamp took its size from the route MTU, and
              # passt's route MTU is 65520, so the rule started rewriting MSS
              # *up* to ~65480 instead of down to ~1460. Removing it restored
              # 5.5 MB/s bulk transfer and 8/8 parallel connections.
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
            # 4096 was not enough. Chromium spawns a process per renderer and
            # is happy to use a gigabyte on a heavy page; sharing that with
            # Android, Play Services and Waydroid meant complex sites froze
            # while video, which needs far less, played fine. The host has
            # 15 GB.
            memorySize = 8192;
            cores = 4;
            diskSize = 16384; # Android system image plus apps
            graphics = true;

            # qemu's default uplink is SLIRP, a TCP/IP stack reimplemented in
            # userspace. It is fine for one transfer at a time — which is
            # exactly what every measurement here used, and why the network
            # kept "measuring healthy" — but it is a known-weak point for what
            # apps actually do: many parallel connections and long-lived ones.
            # passt is the modern replacement, still unprivileged, but with a
            # far more correct stack. qemu >= 9.2 spawns it itself.
            #
            # This replaces networkingOptions wholesale, so
            # virtualisation.forwardPorts no longer applies — the ssh forward
            # that keeps this guest debuggable moves to passt's tcp-ports.
            # mkForce because qemu-vm.nix *defines* this list rather than only
            # defaulting it, so a plain assignment concatenates and the guest
            # ends up with both uplinks.
            qemu.networkingOptions = lib.mkForce [
              "-netdev passt,id=net0,path=${pkgs.passt}/bin/passt,tcp-ports=2222:22"
              "-device virtio-net-pci,netdev=net0"
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
            script =
              let
                # A real Pixel 5 build, taken from a device dump rather than
                # invented: TQ3A.230901.001 is also the build id this image
                # already reports, so nothing contradicts the base system.
                fp = "google/redfin/redfin:13/TQ3A.230901.001/10750268:user/release-keys";
                desc = "redfin-user 13 TQ3A.230901.001 10750268 release-keys";
                buildId = "TQ3A.230901.001";
                incremental = "10750268";

                # Android keeps a separate copy of the identity on every
                # partition, and a scan found five of them still announcing
                # "WayDroid arm64 only Device" on userdebug/test-keys while
                # the base properties claimed to be a Pixel. Generate the
                # whole matrix instead of listing it by hand, which is how
                # system_ext and vendor_dlkm got missed the first time.
                idParts = [ "system" "system_ext" "vendor" "vendor_dlkm" "odm" "product" ];
                buildParts = idParts ++ [ "bootimage" ];

                identity = {
                  brand = "google";
                  manufacturer = "Google";
                  name = "redfin";
                  device = "redfin";
                  model = "Pixel 5";
                };

                mkIdent =
                  prefix:
                  lib.concatMapStringsSep "\n" (k: "ro.product.${prefix}${k}=${identity.${k}}") (
                    builtins.attrNames identity
                  );

                mkBuild = prefix: ''
                  ro.${prefix}build.fingerprint=${fp}
                  ro.${prefix}build.id=${buildId}
                  ro.${prefix}build.tags=release-keys
                  ro.${prefix}build.type=user
                  ro.${prefix}build.version.incremental=${incremental}
                '';

                propText = ''
                  ro.debuggable=0
                  ${mkIdent ""}
                  ${lib.concatMapStringsSep "\n" (p: mkIdent "${p}.") idParts}
                  ro.build.product=redfin
                  ro.build.flavor=redfin-user
                  ro.build.display.id=${buildId}
                  ro.build.description=${desc}
                  ro.build.version.security_patch=2023-09-05
                  ro.build.user=android-build
                  ro.build.host=abfarm-release
                  ${mkBuild ""}
                  ${lib.concatMapStringsSep "\n" (p: mkBuild "${p}.") buildParts}
                  ro.system.build.product=redfin
                  ro.system.build.flavor=redfin-user
                  ro.system.build.description=${desc}
                  ro.system_ext.build.description=${desc}
                  ro.vendor.build.security_patch=2023-09-05

                  # Play Integrity reads FIRST_API_LEVEL directly. The Pixel 5
                  # shipped on Android 11, so claiming 33 here contradicts the
                  # fingerprint.
                  ro.product.first_api_level=30
                  ro.board.first_api_level=30

                  # These exist only on custom ROMs; their mere presence gives
                  # the game away, and they cannot be deleted from a read-only
                  # image, so blank them.
                  ro.lineage.version=
                  ro.lineage.display.version=
                  ro.lineage.build.version=
                  ro.lineage.device=
                  ro.lineage.releasetype=
                  ro.modversion=
                '';
              in
              ''
                f=/var/lib/waydroid/waydroid_base.prop
                [ -e "$f" ] || exit 0
                # Drop anything this service wrote on a previous boot so the
                # block below is authoritative rather than accumulating.
                ${pkgs.gnused}/bin/sed -i \
                  -e '/^qemu\.hw\.mainkeys=/d' \
                  -e '/^persist\.waydroid\.width=/d' \
                  -e '/^persist\.waydroid\.height=/d' \
                  -e '/^ro\.product\./d' \
                  -e '/^ro\.build\./d' \
                  -e '/^ro\.[a-z_]*\.build\./d' \
                  -e '/^ro\.board\.first_api_level=/d' \
                  -e '/^ro\.lineage\./d' \
                  -e '/^ro\.modversion=/d' \
                  -e '/^ro\.debuggable=/d' "$f"

                # Google refuses to finish its embedded sign-in flow on a
                # device advertising itself as "linux,dummy-virt" on a
                # userdebug/test-keys build — the page loads fine and simply
                # never reports ready, which reads as "Checking info..."
                # forever. Every one of these has to agree: a half-spoofed
                # device (release-keys tags but a userdebug type, or a
                # fingerprint whose build id does not match ro.build.id) is
                # more obviously fake than an honest one.
                cat >> "$f" <<'PROPEOF'
${propText}
PROPEOF
                # The generated block is indented for readability.
                ${pkgs.gnused}/bin/sed -i 's/^[[:space:]]*//' "$f"
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
