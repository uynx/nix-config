{
  # Plain aarch64, not Apple Silicon (that is hardware/asahi.nix).
  # STUB: no such machine exists yet. Adjust bootloader before first install.
  flake.nixosModules.hardwareArm = {
    boot.loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };
}
