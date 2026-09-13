{ moduleWithSystem, ... }:
{
  flake.wrappers.btop =
    { wlib, pkgs, ... }:
    {
      imports = [ wlib.wrapperModules.btop ];
      package = if pkgs.stdenv.hostPlatform.isx86_64 then pkgs.btop-cuda else pkgs.btop;
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
