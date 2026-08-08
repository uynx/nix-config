{ self, ... }:
let
  bundle = self.lib.mkBundle {
    home = [ self.homeModules.office ];
    darwin = [ self.darwinModules.officeCasks ];
  };
in
{
  # Notes and the office suite. Portable, and the bundle the family machines
  # actually want. LibreOffice has no darwin build in nixpkgs, so the macOS
  # half is a cask.
  flake.nixosModules.office = bundle.nixos;
  flake.darwinModules.office = bundle.darwin;
}
