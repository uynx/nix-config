{ self, lib, ... }:
let
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
          server_names = lib.attrNames stamps;
          static = lib.mapAttrs (_: stamp: { inherit stamp; }) stamps;
          doh_servers = true;
          require_dnssec = false;

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
              curl -fsSL --retry 3 --retry-all-errors --retry-delay 2 --connect-timeout 10 --max-time 60 -o "$work/$f" "$base/$f"
            done

            minisign -Vqm "$work/public-resolvers.md" \
              -P RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3

            for name in $(jq -r 'keys[]' "$file"); do
              latest=$(awk -v h="## $name" \
                '$0 == h { f = 1; next } f && /^sdns:\/\// { print; exit }' \
                "$work/public-resolvers.md")
              current=$(jq -r --arg n "$name" '.[$n]' "$file")

              if [ -z "$latest" ]; then
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

  flake.darwinModules.dnscrypt =
    { config, lib, ... }:
    {
      imports = [ shared ];

      launchd.daemons.dnscrypt-proxy.serviceConfig.UserName = lib.mkForce "root";

      launchd.daemons.dnscrypt-proxy.serviceConfig.ProgramArguments = lib.mkForce [
        "/bin/sh"
        "-c"
        ''
          /bin/wait4path /nix/store
          i=0
          while [ "$i" -lt 20 ]; do
            /sbin/route -n get default >/dev/null 2>&1 && /sbin/route -n get -inet6 default >/dev/null 2>&1 && break
            i=$((i + 1))
            sleep 1
          done
          exec ${config.launchd.daemons.dnscrypt-proxy.command}
        ''
      ];

      networking.knownNetworkServices = [
        "Wi-Fi"
        "USB 10/100/1000 LAN"
        "Thunderbolt Bridge"
        "iPhone USB"
      ];
      networking.dns = [ "127.0.0.1" ];

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
