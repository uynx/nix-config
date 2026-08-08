{
  # Wallpaper on macOS. Same image the niri host uses, taken from the repo
  # rather than ~/dotfiles so a fresh Mac has it before anything is cloned.
  flake.homeModules.desktoppr = {
    programs.desktoppr = {
      enable = true;
      settings = {
        # Interpolated, not a bare path: desktoppr's plist is generated outside
        # the module system, where a raw path loses its store context.
        picture = "${../../wallpapers/wallpaper.png}";
        scale = "fill";
      };
    };
  };
}
