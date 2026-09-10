{
  flake.nixosModules.bluetooth = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.overskride ];

    hardware.bluetooth.enable = true;
  };
}
