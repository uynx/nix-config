{ lib, ... }:
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
      # Unbinding dwc3-apple oopses the kernel without this — still true at
      # asahi-wip, so do not drop it on a kernel bump without rechecking.
      kernelPatches = [
        {
          name = "dwc3-apple-set-drvdata";
          patch = ./dwc3-apple-set-drvdata.patch;
        }
        {
          name = "pstore-console";
          patch = null;
          # Without this, ramoops' console_size is silently inert — and the
          # continuous console log is the only thing that survives a wake-up
          # hang, since a hang never reaches the oops/panic dumper at all.
          structuredExtraConfig.PSTORE_CONSOLE = lib.kernel.yes;
        }
      ];
      # ramoops keeps the kernel log in reserved RAM across a reset, so the
      # watchdog reboot after a hang leaves it readable in /sys/fs/pstore.
      # no_console_suspend is required or nothing is recorded across the
      # suspend/resume window, which is the window under investigation.
      kernelModules = [ "ramoops" ];
      kernelParams = [
        "zswap.enabled=1"
        "zswap.compressor=zstd"
        "zswap.shrinker_enabled=1"
        "reserve_mem=8M:16384:oops"
        "ramoops.mem_name=oops"
        "ramoops.console_size=4M"
        "ramoops.record_size=1M"
        "no_console_suspend"
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
    # it back, and nothing re-enumerates until the cable is replugged. Rebinding
    # re-runs probe, which is what the replug was doing by hand. Only safe with
    # the dwc3-apple drvdata patch above — without it every resume oopses.
    powerManagement.resumeCommands = ''
      for d in /sys/bus/platform/drivers/dwc3-apple/*.usb; do
        echo "''${d##*/}" > /sys/bus/platform/drivers/dwc3-apple/unbind || true
        echo "''${d##*/}" > /sys/bus/platform/drivers/dwc3-apple/bind || true
      done
    '';

    # A wedge becomes a reboot instead of a held power button. systemd pings the
    # SoC watchdog from PID 1, so it fires even when the kernel stops scheduling.
    systemd.settings.Manager.RuntimeWatchdogSec = "2min";

    # Headroom for Hogwarts / muvm guest memory pressure.
    swapDevices = [
      {
        device = "/swapfile";
        size = 16384;
      }
    ];
  };
}
