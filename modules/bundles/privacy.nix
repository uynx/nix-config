{ self, ... }:
{
  # VPN plus the anonymity browsers. Obscura installs a default-deny egress
  # table at boot, so dropping this bundle also drops the machine's firewall
  # posture down to `system/security.nix` alone.
  flake.nixosModules.privacy = self.lib.mkBundle {
    nixos = [ self.nixosModules.obscura ];
    home = [ self.homeModules.privacyBrowsers ];
  };
}
