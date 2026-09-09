{ ... }:
{
  # x86's answer to steamAsahi in default.nix/home.nix — no container, the
  # host GPU already runs Steam directly.
  flake.nixosModules.steamNative = {
    programs.steam.enable = true;
    hardware.graphics.enable32Bit = true;
  };
}
