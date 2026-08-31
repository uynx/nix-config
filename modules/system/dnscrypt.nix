{ self, lib, ... }:
let
  # Static stamps rather than a resolver list: nothing to fetch before DNS
  # works, and the pair is v4/v6 of the same `all.dns.mullvad.net` endpoint.
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
          server_names = [
            "mullvad-all-doh"
            "mullvad-all-doh-v6"
          ];
          doh_servers = true;
          require_dnssec = false;
          static = {
            mullvad-all-doh.stamp = "sdns://AgIAAAAAAAAADzE5NC4yNDIuMi45OjQ0MwATYWxsLmRucy5tdWxsdmFkLm5ldAovZG5zLXF1ZXJ5";
            mullvad-all-doh-v6.stamp = "sdns://AgIAAAAAAAAAElsyYTA3OmUzNDA6OjldOjQ0MwATYWxsLmRucy5tdWxsdmFkLm5ldAovZG5zLXF1ZXJ5";
          };

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
