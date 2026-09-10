{
  flake.homeModules.aerospace =
    { config, ... }:
    {
      programs.aerospace = {
        enable = true;
        launchd = {
          enable = true;
          keepAlive = true;
        };
      };

      home.file.".aerospace.toml".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/aerospace.toml";
    };
}
