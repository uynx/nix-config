{ moduleWithSystem, ... }:
{
  flake.wrappers.btop =
    { wlib, ... }:
    {
      imports = [ wlib.wrapperModules.btop ];
      settings.color_theme = "flexoki";
      themes.flexoki = ./flexoki.theme;
    };

  flake.homeModules.btop = moduleWithSystem (
    { self', ... }:
    {
      home.packages = [ self'.packages.btop ];
    }
  );
}
