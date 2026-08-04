{ self, ... }:
{
  # Config is baked into the derivation, so changing a setting means a rebuild.
  flake.wrappers.btop =
    { wlib, ... }:
    {
      imports = [ wlib.wrapperModules.btop ];
      settings.color_theme = "flexoki";
      themes.flexoki = ./flexoki.theme;
    };

  # Indexed by evaluating system rather than self' so this stays a plain home
  # module any host can import.
  flake.homeModules.btop =
    { pkgs, ... }:
    {
      home.packages = [ self.packages.${pkgs.stdenv.hostPlatform.system}.btop ];
    };
}
