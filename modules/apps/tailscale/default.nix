{
  flake.nixosModules.tailscale =
    { config, lib, ... }:
    let
      peers = {
        agent = "100.84.155.23";
        asahi = "100.125.81.50";
        x86 = "100.75.113.17";
      };
    in
    {
      sops.secrets.tailscale-authkey = { };
      services.tailscale = {
        enable = true;
        openFirewall = true;
        authKeyFile = config.sops.secrets.tailscale-authkey.path;
        # MagicDNS would replace dnscrypt as the resolver.
        extraUpFlags = [ "--accept-dns=false" ];
      };
      networking.hosts = lib.mapAttrs' (name: ip: lib.nameValuePair ip [ name ]) (
        lib.filterAttrs (name: _: name != config.networking.hostName) peers
      );
      networking.firewall.trustedInterfaces = [ "tailscale0" ];
    };
}
