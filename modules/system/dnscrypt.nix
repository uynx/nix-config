{ self, lib, ... }:
let
  # Names are upstream's, because `update-dns-stamps` looks each one up by
  # heading in public-resolvers.md. Renaming one here silently stops it
  # updating.
  stamps = lib.importJSON ./dns-stamps.json;

  shared =
    { pkgs, ... }:
    {
      services.dnscrypt-proxy = {
        enable = true;
        settings = {
          listen_addresses = [
            "127.0.0.1:53"
            "[::1]:53"
          ];
          # Static entries rather than a resolver list: nothing to fetch before
          # DNS works. `require_nolog`/`require_nofilter` from the upstream
          # defaults only screen servers taken from sources, which is the only
          # reason an ads-and-trackers filtering resolver is reachable this way.
          server_names = lib.attrNames stamps;
          static = lib.mapAttrs (_: stamp: { inherit stamp; }) stamps;
          doh_servers = true;
          require_dnssec = false;

          # Answered from this file unconditionally, never forwarded — which is
          # the point: on a captive network the upstream is unreachable, so
          # without it the OS probe gets SERVFAIL, reads that as "no internet"
          # rather than "portal", and never offers a login window. Several
          # anycast addresses because a dead pin means a permanent false
          # "portal detected" on healthy networks.
          captive_portals.map_file = pkgs.writeText "captive-portals.txt" ''
            captive.apple.com 17.253.125.203, 17.253.125.201, 17.253.109.201, 17.253.113.202
          '';
        };
      };

      home-manager.users.${self.lib.user.name} = {
        home.packages = [
          (pkgs.writers.writeDashBin "update-dns-stamps" ''
            set -eu
            export PATH=${
              lib.makeBinPath (
                with pkgs;
                [
                  coreutils
                  curl
                  gawk
                  jq
                  minisign
                ]
              )
            }

            base=https://download.dnscrypt.info/resolvers-list/v3
            file=$HOME/nix-config/modules/system/dns-stamps.json

            work=$(mktemp -d)
            trap 'rm -rf "$work"' EXIT INT TERM

            for f in public-resolvers.md public-resolvers.md.minisig; do
              curl -fsSL --connect-timeout 10 --max-time 60 -o "$work/$f" "$base/$f"
            done

            # This list decides where every DNS query on this machine goes, and
            # dnscrypt-proxy verifies it at runtime with exactly this key.
            # Pinning the stamps moves the fetch offline, so the check has to
            # move with it — TLS alone would be a downgrade.
            minisign -Vqm "$work/public-resolvers.md" \
              -P RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3

            for name in $(jq -r 'keys[]' "$file"); do
              latest=$(awk -v h="## $name" \
                '$0 == h { f = 1; next } f && /^sdns:\/\// { print; exit }' \
                "$work/public-resolvers.md")
              current=$(jq -r --arg n "$name" '.[$n]' "$file")

              if [ -z "$latest" ]; then
                # Keeping the stale stamp is the safe failure: a delisted
                # resolver is rarely dead the same day, an empty pin is
                # instant, and `update` must still reach the flake relock.
                printf '%-22s FAILED (not in public-resolvers.md — pin left stale)\n' "$name"
              elif [ "$latest" = "$current" ]; then
                printf '%-22s up to date\n' "$name"
              else
                tmp=$(mktemp)
                jq --arg n "$name" --arg s "$latest" '.[$n] = $s' "$file" >"$tmp"
                mv "$tmp" "$file"
                printf '%-22s stamp changed\n' "$name"
              fi
            done
          '')
        ];

        shellHooks.update = [ "update-dns-stamps" ];
      };
    };
in
{
  flake.nixosModules.dnscrypt = shared;

  flake.darwinModules.dnscrypt = {
    imports = [ shared ];

    # nix-darwin runs the daemon as `_dnscrypt-proxy`, which cannot bind port
    # 53 — macOS reserves everything below 1024 for uid 0. Dropping privileges
    # via dnscrypt's own `user_name` is not an option either: it re-execs and
    # the parent exits, which KeepAlive reads as a crash and restarts forever.
    launchd.daemons.dnscrypt-proxy.serviceConfig.UserName = lib.mkForce "root";

    # macOS has no global resolver setting; DNS is per network service, and
    # these are every service this Mac has. Check `networksetup
    # -listallnetworkservices` after adding a new adapter.
    networking.knownNetworkServices = [
      "Wi-Fi"
      "USB 10/100/1000 LAN"
      "Thunderbolt Bridge"
      "iPhone USB"
    ];
    networking.dns = [ "127.0.0.1" ];

    # The detection map above gets the login window to appear; a portal page
    # that pulls assets from its own hostnames still needs a resolver that
    # answers on the far side of it. dnscrypt never falls back to plaintext, so
    # that hand-off has to be manual. `reb` puts 127.0.0.1 back too.
    home-manager.users.${self.lib.user.name}.programs.fish.functions.portal.body = ''
      switch "$argv[1]"
          case on
              sudo networksetup -setdnsservers Wi-Fi empty
              open -a "Captive Network Assistant"
          case off
              sudo networksetup -setdnsservers Wi-Fi 127.0.0.1
          case '*'
              echo "portal on   hand DNS back to the network, open the login window"
              echo "portal off  encrypted DNS again"
              networksetup -getdnsservers Wi-Fi
      end
    '';
  };
}
