{ moduleWithSystem, ... }:
{
  # Config is baked into the derivation, so changing a setting means a rebuild.
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
