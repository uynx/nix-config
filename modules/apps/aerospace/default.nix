{
  # Tiling window manager for macOS. The config is an out-of-store symlink into
  # ~/dotfiles for the same reason niri's is not: it is tuned live, and
  # AeroSpace re-reads it on `reload-config` without a rebuild.
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
