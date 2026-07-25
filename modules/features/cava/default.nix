{
  flake.homeModules.cava = { pkgs, ... }: {
    home.packages = [ pkgs.cava ];
    home.file.".config/cava/config".text = ''
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
}
