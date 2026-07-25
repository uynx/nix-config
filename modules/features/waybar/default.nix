{
  flake.homeModules.waybar =
    { config, pkgs, ... }:
    let
      home = "/home/uynx";
    in
    {
      programs.waybar.enable = true;

      # cava is not standalone: waybar's custom/cava module pipes its raw ascii
      # output through sed to draw the block-character spectrum in the bar.
      home.packages = [ pkgs.cava ];

      home.file = {
        ".config/waybar".source = config.lib.file.mkOutOfStoreSymlink "${home}/dotfiles/waybar";
        ".config/cava/config".text = ''
          [general]
          bars = 16
          framerate = 60
          [input]
          method = pipewire
          source = auto
          [output]
          method = raw
          raw_target = /dev/stdout
          data_format = ascii
          ascii_max_range = 7
        '';
      };
    };
}
