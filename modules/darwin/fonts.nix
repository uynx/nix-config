{
  # The darwin twin of `system/fonts.nix`. macOS ships the text faces; only the
  # ones the terminal and the status bar name are needed here.
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
