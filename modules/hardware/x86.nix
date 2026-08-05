{
  # STUB: no such machine exists yet. Pick a GPU driver set on first install —
  # amdgpu and intel need different packages, so that choice belongs here.
  flake.nixosModules.hardwareX86 = {
    boot.loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    hardware.enableRedistributableFirmware = true;
  };
}
