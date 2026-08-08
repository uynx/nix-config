{ self, ... }:
let
  bundle = self.lib.mkBundle {
    nixos = [ self.nixosModules.obscura ];
    # The `vpn` command and reb's post-switch daemon restart; both drive the
    # units above, so they only exist where those units do.
    homeLinux = with self.homeModules; [
      privacyBrowsers
      obscura
    ];
    # Both browsers are repackaged Linux tarballs there and Obscura ships a
    # signed .app, so all three are casks on macOS.
    darwin = with self.darwinModules; [
      privacyBrowsers
      obscura
    ];
  };
in
{
  # VPN plus the anonymity browsers. Obscura installs a default-deny egress
  # table at boot, so dropping this bundle also drops the machine's firewall
  # posture down to `system/security.nix` alone.
  flake.nixosModules.privacy = bundle.nixos;
  flake.darwinModules.privacy = bundle.darwin;
}
