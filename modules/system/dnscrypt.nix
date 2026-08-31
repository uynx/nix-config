{ lib, ... }:
let
  # Static stamps rather than a resolver list: nothing to fetch before DNS
  # works, and the pair is v4/v6 of the same `all.dns.mullvad.net` endpoint.
  shared = {
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
  };
}
