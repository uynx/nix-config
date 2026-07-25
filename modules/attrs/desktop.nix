{ self, ... }:
{
  flake.homeModules.desktopHome = {
    imports = with self.homeModules; [
      theme
      hyprland
      waybar
      noctalia
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
