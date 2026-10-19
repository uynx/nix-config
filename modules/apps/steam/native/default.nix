_: {
  flake.nixosModules.steamNative = {
    programs.steam.enable = true;
    programs.gamescope.enable = true;
    hardware.graphics.enable32Bit = true;
  };
}
