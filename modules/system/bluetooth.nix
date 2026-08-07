{
  # Not blueman: its resident tray applet opened a window on every connect, and
  # a flapping device means dozens. overskride runs on demand, and is only
  # needed to pair or scan — noctalia's panel handles paired devices.
  flake.nixosModules.bluetooth = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.overskride ];

    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings.General.AutoEnable = true;
    };
  };
}
