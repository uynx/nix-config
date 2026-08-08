{
  flake.nixosModules.hardwareAsahi = {
    hardware.asahi = {
      enable = true;
      # Keep as a real path. The module reads firmware.cpio out of this at build
      # time, and a context-free string is invisible inside the sandbox. This is
      # why rebuilds need --impure.
      peripheralFirmwareDirectory = /boot/vendorfw;
    };

    boot = {
      loader.systemd-boot.enable = true;
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

    # A greeter grabs the lowest-numbered DRM card, which before apple-drm binds
    # is U-Boot's simpledrm on card0 — the node that binding tears down. It then
    # dies on drmModeGetResources and the display manager logs it as success.
    # Hardware, not greeter config, so it applies whichever desktop is selected.
    systemd.services.display-manager = {
      preStart = "until [ -e /dev/dri/by-path/platform-soc:display-subsystem-card ]; do sleep 0.2; done";
      serviceConfig.TimeoutStartSec = "60s";
    };

    # s2idle drops the ATC PHY's port power without telling the xHC how to get
    # it back: the controller reinits, every device reports a disconnect, and
    # nothing re-enumerates until the cable is physically replugged. Rebinding
    # dwc3-apple re-runs probe, which is what a replug was doing by hand.
    powerManagement.resumeCommands = ''
      for d in /sys/bus/platform/drivers/dwc3-apple/*.usb; do
        echo "''${d##*/}" > /sys/bus/platform/drivers/dwc3-apple/unbind || true
        echo "''${d##*/}" > /sys/bus/platform/drivers/dwc3-apple/bind || true
      done
    '';

    # Headroom for Hogwarts / muvm guest memory pressure.
    swapDevices = [
      {
        device = "/swapfile";
        size = 16384;
      }
    ];
  };
}
