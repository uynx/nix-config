{ self, ... }:
{
  # Language toolchains, git and the editor. Portable.
  flake.nixosModules.programming =
    (self.lib.mkBundle {
      home = with self.homeModules; [
        dev
        git
        nvim
      ];
    }).nixos;

  # colima is the container runtime on macOS, where there is no host Docker.
  flake.darwinModules.programming =
    (self.lib.mkBundle {
      home = with self.homeModules; [
        dev
        git
        nvim
        colima
      ];
    }).darwin;
}
