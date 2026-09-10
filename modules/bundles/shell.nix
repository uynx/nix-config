{ self, ... }:
let
  bundle = self.lib.mkBundle {
    home = with self.homeModules; [
      fish
      ghostty
      tmux
      starship
      yazi
      btop
      cli
    ];
  };
in
{
  flake.nixosModules.shell = bundle.nixos;
  flake.darwinModules.shell = bundle.darwin;
}
