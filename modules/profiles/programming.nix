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
      sops
      latex
      starship
      yazi
    ];
  };
}
