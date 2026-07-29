{ self, ... }:
{
  flake.homeModules.programming = {
    imports = with self.homeModules; [
      dev
      git
      nvim
      cli
      btop
      gpg
      latex
    ];
  };
}
