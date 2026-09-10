{ ... }:
{
  flake.nixosModules.steamNative = {
    programs.steam.enable = true;
    hardware.graphics.enable32Bit = true;
  };
}
