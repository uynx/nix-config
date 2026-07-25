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
      cava
      media
      apps
      aiTools
      braveOrigin
    ];
  };
}
