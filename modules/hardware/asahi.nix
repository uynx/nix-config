_: {
  flake.nixosModules.hardwareAsahi = {
    hardware.asahi = {
      enable = true;
      # Keep as a real path. The module reads firmware.cpio out of this at build
      # time, and a context-free string is invisible inside the sandbox. This is
      # why rebuilds need --impure.
      peripheralFirmwareDirectory = /boot/vendorfw;
    };

    boot = {
      loader.systemd-boot = {
        enable = true;
        # The ESP is 476M and only ~350M of that is ours; a kernel/initrd pair
        # is 94M. Unbounded, two kernel bumps fill it and activation dies
        # mid-write with ENOSPC.
        configurationLimit = 10;
      };
      # lz4 must be in the initrd: zswap picks its compressor at init, and an
      # absent module silently leaves it on the built-in default.
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
      # zswap keeps most reclaimed anon pages in RAM compressed, so paging one
      # out is far cheaper than the default 60 assumes. 100 stops the kernel
      # evicting file cache first. Revert if swap churn ever shows up on disk.
      kernel.sysctl."vm.swappiness" = 100;

      extraModprobeConfig = ''
        options hid_apple iso_layout=0
        options uvcvideo quirks=0x80
      '';
    };

    # A greeter grabs the lowest-numbered DRM card, which before apple-drm binds
    # is U-Boot's simpledrm on card0 — the node that binding tears down. It then
    # dies on drmModeGetResources and the display manager logs it as success.
    # Hardware, not greeter config, so it applies whichever desktop is selected.
    systemd.services.display-manager = {
      preStart = "until [ -e /dev/dri/by-path/platform-soc:display-subsystem-card ]; do sleep 0.2; done";
      serviceConfig.TimeoutStartSec = "60s";
    };

    # s2idle never completes here: apple-drm's suspend callback returns -22, so
    # the kernel aborts and resumes immediately. logind's idle retry then loops
    # every ~30 s, and each bounce re-associates Wi-Fi on a fresh randomized MAC
    # until the router's DHCP pool is exhausted. Lid must lock, never suspend;
    # noctalia's `idle.suspendTimeout` is 0 for the same reason.
    services.logind.settings.Login = {
      HandleLidSwitch = "lock";
      HandleLidSwitchExternalPower = "lock";
    };

    # A wedge becomes a reboot instead of a held power button. systemd pings the
    # SoC watchdog from PID 1, so it fires even when the kernel stops scheduling.
    systemd.settings.Manager.RuntimeWatchdogSec = "2min";

    # Headroom for muvm guest memory pressure; Venus VRAM sits outside the
    # guest RAM cap, so the host runs out first.
    swapDevices = [
      {
        device = "/swapfile";
        size = 16384;
      }
    ];
  };
}
