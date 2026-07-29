{ self, ... }:
{
  flake.homeModules.desktopHome = {
    imports = with self.homeModules; [
      theme
      niri
      launchers
      noctalia
      ghostty
      fish
      tmux
      media
      gui
      screenUtils
      aiTools
      braveOrigin
    ];
  };
}
