{
  # GTX 1070 (Pascal). Both NVIDIA pins below are forced by the hardware, not
  # preferences: 580 is the last branch carrying Maxwell/Pascal/Volta (nixpkgs'
  # `stable` has already moved to 595, which drops them) and the open kernel
  # modules need Turing or newer for GSP firmware Pascal does not have.
  # nixpkgs marks 580 an LTSB supported until Aug 2028.
  flake.nixosModules.hardwareX86 =
    { config, ... }:
    {
      boot.loader = {
        systemd-boot.enable = true;
        efi.canTouchEfiVariables = true;
      };
      hardware.enableRedistributableFirmware = true;

      services.xserver.videoDrivers = [ "nvidia" ];
      hardware.graphics.enable = true;
      hardware.nvidia = {
        package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
        open = false;
        # Without this the proprietary driver has no DRM KMS, and every Wayland
        # compositor including niri refuses to start on it.
        modesetting.enable = true;
      };
    };
}
