{
  flake.nixosModules.tailscale =
    { config, ... }:
    {
      sops.secrets.tailscale-authkey = { };
      services.tailscale = {
        enable = true;
        openFirewall = true;
        authKeyFile = config.sops.secrets.tailscale-authkey.path;
        # MagicDNS would replace dnscrypt as the resolver.
        extraUpFlags = [ "--accept-dns=false" ];
      };
      networking.firewall.trustedInterfaces = [ "tailscale0" ];
    };
}
