_: {
  flake.nixosModules.hardwareAsahi = { lib, ... }: {
    hardware.asahi = {
      enable = true;
      # A real path, not a string: read at build time, hence rebuilds needing --impure.
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
      kernel.sysctl = {
        "vm.swappiness" = 100;
        "vm.vfs_cache_pressure" = 50;
      };

      extraModprobeConfig = ''
        options hid_apple iso_layout=0
        options uvcvideo quirks=0x80
      '';
    };

    systemd = {
      services.display-manager = {
        preStart = "until [ -e /dev/dri/by-path/platform-soc:display-subsystem-card ]; do sleep 0.2; done";
        serviceConfig.TimeoutStartSec = "60s";
      };

      # apple-drm cannot suspend; every attempt wedges the machine - do not re-enable
      sleep.settings.Sleep.AllowSuspend = false;

      settings.Manager.RuntimeWatchdogSec = "2min";
    };

    services.logind.settings.Login = {
      HandleLidSwitch = "lock";
      HandleLidSwitchExternalPower = "lock";
      HandlePowerKey = "lock";
    };

    services.udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x17a0", ATTR{device}=="0x9755", ATTR{power/control}="auto"
    '';

    swapDevices = [
      {
        device = "/swapfile";
        size = 16384;
      }
    ];
  };
}
