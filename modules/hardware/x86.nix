{
  flake.nixosModules.hardwareX86 =
    { config, pkgs, ... }:
    {
      boot = {
        loader = {
          systemd-boot = {
            enable = true;
            configurationLimit = 10;
            bootCounting = {
              enable = true;
              tries = 2;
            };
          };
          efi.canTouchEfiVariables = true;
        };
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

      # A new generation that gets no route in 4 minutes reboots; after its second failed try systemd-boot falls back to the previous generation.
      systemd.services.boot-health = {
        description = "Reboot when a freshly installed generation boots without network";
        requiredBy = [ "boot-complete.target" ];
        before = [ "boot-complete.target" ];
        after = [ "NetworkManager.service" ];
        unitConfig = {
          ConditionPathExists = "/sys/firmware/efi/efivars/LoaderBootCountPath-4a67b082-0a4c-41cf-b6c7-440b29bb8c4f";
          OnFailure = "reboot.target";
        };
        restartIfChanged = false;
        path = [
          pkgs.iproute2
          pkgs.ripgrep
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          TimeoutStartSec = 240;
        };
        script = "until ip -4 route show default | rg -q 'dev (wl|en)'; do sleep 3; done";
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
