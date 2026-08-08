{ self, ... }:
let
  bundle = self.lib.mkBundle {
    home = with self.homeModules; [
      dev
      git
      nvim
    ];
    # colima is the container runtime on macOS, where there is no host Docker.
    homeDarwin = [ self.homeModules.colima ];
  };
in
{
  # Language toolchains, git and the editor. Portable.
  flake.nixosModules.programming = bundle.nixos;
  flake.darwinModules.programming = bundle.darwin;
}
