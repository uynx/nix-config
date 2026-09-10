{
  flake.homeModules.desktoppr = {
    programs.desktoppr = {
      enable = true;
      settings = {
        picture = "${../../wallpapers/wallpaper.png}";
        scale = "fill";
      };
    };
  };
}
