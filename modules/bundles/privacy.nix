{ self, ... }:
let
  bundle = self.lib.mkBundle {
    nixos = [ self.nixosModules.obscura ];
    homeLinux = [ self.homeModules.privacyBrowsers ];
    # Both browsers are repackaged Linux tarballs there and Obscura ships a
    # signed .app, so all three are casks on macOS.
    darwin = [ self.darwinModules.privacyCasks ];
  };
in
{
  # VPN plus the anonymity browsers. Obscura installs a default-deny egress
  # table at boot, so dropping this bundle also drops the machine's firewall
  # posture down to `system/security.nix` alone.
  flake.nixosModules.privacy = bundle.nixos;
  flake.darwinModules.privacy = bundle.darwin;
}
