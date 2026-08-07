{ self, ... }:
{
  # Language toolchains, git and the editor. Portable.
  flake.nixosModules.programming = self.lib.mkBundle {
    home = with self.homeModules; [
      dev
      git
      nvim
    ];
  };
}
