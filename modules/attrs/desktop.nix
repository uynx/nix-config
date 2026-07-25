{ self, ... }:
{
  flake.homeModules.desktopHome = {
    imports = with self.homeModules; [
      theme
      niri
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
