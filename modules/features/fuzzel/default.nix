{
  flake.homeModules.fuzzel =
    { config, ... }:
    let
      home = "/home/uynx";
    in
    {
      home.file.".config/fuzzel/fuzzel.ini".source =
        config.lib.file.mkOutOfStoreSymlink "${home}/dotfiles/fuzzel/fuzzel.ini";
    };
}
