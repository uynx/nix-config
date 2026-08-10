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
      loader.systemd-boot = {
        enable = true;
        # The ESP is 476M and only ~350M of that is ours; a kernel/initrd pair
        # is 94M. Unbounded, two kernel bumps fill it and activation dies
        # mid-write with ENOSPC.
        configurationLimit = 10;
      };
      kernelPatches = [
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
        # Raw bytes. Module params are parsed with kstrtoul, which rejects the
        # K/M/G suffixes that `reserve_mem` above accepts — "4M" makes ramoops
        # refuse to load at all, and pstore then records nothing.
        "ramoops.console_size=4194304"
        "ramoops.record_size=1048576"
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

    # tps6598x_resume() never re-reads port status, so after s2idle the Type-C
    # controller still believes the cable never left and emits no connect event
    # — and every layer below it (mux, ATC PHY, dwc3 core, DP alt-mode) stays
    # torn down until a physical replug. tps6598x_probe() *does* do that check,
    # so rebinding is a replug in software. Rebinding dwc3-apple instead cannot
    # work: its probe only arms a wait for the connect event that never comes.
    # 0-003a is the charging port, left alone so resume never renegotiates PD.
    powerManagement.resumeCommands = ''
      for d in 0-0038 0-003b 0-003f; do
        echo "$d" > /sys/bus/i2c/drivers/tps6598x/unbind || true
        echo "$d" > /sys/bus/i2c/drivers/tps6598x/bind || true
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
