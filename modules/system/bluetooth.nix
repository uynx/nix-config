{
  # Not blueman: its resident tray applet opened a window on every connect, and
  # a flapping device means dozens. overskride runs on demand, and is only
  # needed to pair or scan — noctalia's panel handles paired devices.
  flake.nixosModules.bluetooth = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.overskride ];

    # powerOnBoot defaults true and is what writes bluez' `Policy.AutoEnable`;
    # there is no `General.AutoEnable` for it to be written twice.
    hardware.bluetooth.enable = true;
  };
}
