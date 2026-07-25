{
  # Apple Silicon (Asahi). Specialized ARM.
  flake.nixosModules.hardwareMacbook = {
    hardware.asahi = {
      enable = true;
      peripheralFirmwareDirectory = "/nix/store/jd2gkq3m7c2plcx48bxdsm0xwalcpldw-asahi-peripheral-firmware";
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
