{
  flake.homeModules.waybar =
    { config, ... }:
    let
      home = "/home/uynx";
    in
    {
      programs.waybar.enable = true;
      home.file.".config/waybar".source =
        config.lib.file.mkOutOfStoreSymlink "${home}/dotfiles/waybar";
    };
}
