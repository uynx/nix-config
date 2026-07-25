{
  # Apple Silicon (Asahi). Specialized ARM.
  flake.nixosModules.hardwareMacbook = {
    hardware.asahi = {
      enable = true;
      # Must stay a real path, not a store string: the asahi module reads
      # firmware.cpio out of this at BUILD time, so it has to be a derivation
      # input. A context-free string is invisible inside the build sandbox.
      # This is why rebuilds need --impure.
      peripheralFirmwareDirectory = /boot/vendorfw;
    };

    boot = {
      loader = {
        systemd-boot.enable = true;
        efi.canTouchEfiVariables = false;
      };
      kernelParams = [
        "zswap.enabled=1"
        "zswap.compressor=zstd"
        "zswap.shrinker_enabled=1"
      ];
      extraModprobeConfig = ''
        options hid_apple iso_layout=0
        options uvcvideo quirks=0x80
      '';
    };

    # Headroom for Hogwarts / muvm guest memory pressure.
    swapDevices = [
      {
        device = "/swapfile";
        size = 16384;
      }
    ];
  };
}
