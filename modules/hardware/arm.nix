{
  # Generic aarch64 machine — plain ARM, not Apple Silicon.
  # Asahi-specific firmware and boot handling live in hardware/asahi.nix.
  # STUB: no such machine exists yet. Adjust bootloader before first install.
  flake.nixosModules.hardwareArm = {
    boot.loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };
}
