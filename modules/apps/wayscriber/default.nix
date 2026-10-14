{
  flake.homeModules.wayscriber =
    { config, pkgs, ... }:
    {
      home.packages = [
        (pkgs.wayscriber.overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [ ./zoom-repeat.patch ];
        }))
      ];
      xdg.configFile."wayscriber/config.toml".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix-config/modules/apps/wayscriber/config.toml";
    };
}
