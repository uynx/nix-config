{ self, ... }:
let
  bundle = self.lib.mkBundle {
    home = with self.homeModules; [
      dev
      git
      nvim
    ];
    nixos = [ self.nixosModules.wireshark ];
    homeDarwin = with self.homeModules; [
      colima
      wireshark
    ];
  };
in
{
  flake.nixosModules.programming = bundle.nixos;
  flake.darwinModules.programming = bundle.darwin;
}
