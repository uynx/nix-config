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
  # The fish *NixOS* module (the overlay pointing pkgs.fish at the wrapped
  # build) stays in `core`, because user.nix makes fish the login shell on every
  # host whether or not that host takes this bundle.
  flake.nixosModules.shell = bundle.nixos;
  flake.darwinModules.shell = bundle.darwin;
}
