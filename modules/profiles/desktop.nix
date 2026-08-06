{ self, ... }:
{
  flake.homeModules.desktopHome = {
    imports = with self.homeModules; [
      theme
      launchers
      noctalia
      ghostty
      fish
      tmux
      media
      gui
      rclone
      screenUtils
      aiTools
      braveOrigin
    ];
  };
}
