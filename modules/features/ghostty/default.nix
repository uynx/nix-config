{
  flake.homeModules.ghostty =
    let
      home = "/home/uynx";
    in
    {
      programs.ghostty.enable = true;
      home.file.".config/ghostty/config".text = ''
        config-file = ${home}/dotfiles/ghostty_config
        font-size = 12
      '';
    };
}
