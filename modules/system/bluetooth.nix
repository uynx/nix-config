{
  # No blueman. It is built around a resident tray applet, which opened a window
  # on every connect — with a device that flaps, dozens of them. overskride is
  # launched on demand instead, so there is nothing running to pop anything up.
  #
  # Day to day, noctalia's Bluetooth panel connects and disconnects paired
  # devices; overskride is only needed to pair or scan for a new one, which
  # noctalia cannot do.
  flake.nixosModules.bluetooth = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.overskride ];

    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings.General.AutoEnable = true;
    };
  };
}
