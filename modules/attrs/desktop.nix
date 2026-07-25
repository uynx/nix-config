{ self, ... }:
{
  flake.homeModules.desktopHome = {
    imports = with self.homeModules; [
      theme
      hyprland
      waybar
      fuzzel
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
