{ self, ... }:
{
  flake.homeModules.desktopHome = {
    imports = with self.homeModules; [
      theme
      hyprland
      noctalia
      ghostty
      fish
      tmux
      media
      apps
      aiTools
      braveOrigin
    ];
  };
}
