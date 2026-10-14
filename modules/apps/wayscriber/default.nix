{
  flake.homeModules.wayscriber =
    { config, pkgs, ... }:
    {
      home.packages = [ pkgs.wayscriber ];
      xdg.configFile."wayscriber/config.toml".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix-config/modules/apps/wayscriber/config.toml";
    };
}
