_: {
  flake.nixosModules.hardwareAsahi = {
    hardware.asahi = {
      enable = true;
      peripheralFirmwareDirectory = /boot/vendorfw;
    };

    boot = {
      loader.systemd-boot = {
        enable = true;
        configurationLimit = 10;
      };
      initrd.luks.devices.cryptroot.allowDiscards = true;

      initrd.kernelModules = [
        "lz4"
        "lz4_compress"
      ];
      kernelModules = [
        "lz4"
        "lz4_compress"
      ];
      kernelParams = [
        "zswap.enabled=1"
        "zswap.compressor=lz4"
        "zswap.max_pool_percent=25"
        "zswap.shrinker_enabled=1"
      ];
      kernel.sysctl."vm.swappiness" = 100;

      extraModprobeConfig = ''
        options hid_apple iso_layout=0
        options uvcvideo quirks=0x80
      '';
    };

    systemd.services.display-manager = {
      preStart = "until [ -e /dev/dri/by-path/platform-soc:display-subsystem-card ]; do sleep 0.2; done";
      serviceConfig.TimeoutStartSec = "60s";
    };

    services.logind.settings.Login = {
      HandleLidSwitch = "lock";
      HandleLidSwitchExternalPower = "lock";
    };

    systemd.settings.Manager.RuntimeWatchdogSec = "2min";

    swapDevices = [
      {
        device = "/swapfile";
        size = 16384;
      }
    ];
  };
}
