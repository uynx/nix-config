{ self, ... }:
let
  bundle = self.lib.mkBundle {
    home = [ self.homeModules.rclone ];
  };
in
{
  # Pulls in `sops` itself rather than relying on the secrets bundle being
  # present, so it works on any host.
  flake.nixosModules.cloud = bundle.nixos;
  flake.darwinModules.cloud = bundle.darwin;
}
