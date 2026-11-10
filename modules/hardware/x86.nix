{
  flake.nixosModules.hardwareX86 =
    { config, pkgs, ... }:
    {
      boot = {
        loader.efi.canTouchEfiVariables = true;
        # Keys enroll on the first boot with the firmware in Secure Boot setup mode.
        lanzaboote = {
          enable = true;
          pkiBundle = "/var/lib/sbctl";
          configurationLimit = 10;
          autoGenerateKeys.enable = true;
          autoEnrollKeys.enable = true;
        };
        # TPM slot is enrolled by hand against PCR 7 once Secure Boot is on; the passphrase stays as fallback.
        initrd.luks.devices.cryptroot.crypttabExtraOpts = [ "tpm2-device=auto" ];
        kernelPackages = pkgs.linuxPackages_latest;

        kernelParams = [
          # nct6775 owns I/O ports ACPI also claims; without lax it refuses to bind and VRM/fan sensors vanish.
          "acpi_enforce_resources=lax"
          "nosgx"
        ];
        kernelModules = [ "nct6775" ];

        blacklistedKernelModules = [
          "mei"
          "mei_me"
          "mei_hdcp"
          "mei_pxp"
        ];

        kernel.sysctl = {
          "vm.swappiness" = 180;
          "vm.page-cluster" = 0;
          "vm.vfs_cache_pressure" = 50;
        };
      };

      hardware = {
        enableRedistributableFirmware = true;
        graphics.enable = true;
        nvidia = {
          package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
          open = false;
          modesetting.enable = true;
        };
      };

      services.xserver.videoDrivers = [ "nvidia" ];

      powerManagement.cpuFreqGovernor = "powersave";

      environment.systemPackages = with pkgs; [
        lm_sensors
        sbctl
        stress-ng
      ];

      zramSwap = {
        enable = true;
        algorithm = "zstd";
        memoryPercent = 50;
        priority = 100;
      };

      swapDevices = [
        {
          device = "/swapfile";
          size = 32768;
        }
      ];
    };
}
