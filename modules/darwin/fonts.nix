{
  flake.darwinModules.fonts =
    { pkgs, ... }:
    {
      fonts.packages = with pkgs; [
        nerd-fonts.hack
        julia-mono
        sketchybar-app-font
      ];
    };
}
