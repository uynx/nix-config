{
  flake.nixosModules.hardwareX86 =
    { config, pkgs, ... }:
    {
      boot.loader = {
        systemd-boot.enable = true;
        efi.canTouchEfiVariables = true;
      };
      boot.kernelPackages = pkgs.linuxPackages_latest;
      hardware.enableRedistributableFirmware = true;

      services.xserver.videoDrivers = [ "nvidia" ];
      hardware.graphics.enable = true;
      hardware.nvidia = {
        package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
        open = false;
        modesetting.enable = true;
      };

      powerManagement.cpuFreqGovernor = "powersave";

      boot.kernelParams = [
        # nct6775 owns I/O ports ACPI also claims; without lax it refuses to bind and VRM/fan sensors vanish.
        "acpi_enforce_resources=lax"
        "nosgx"
      ];
      boot.kernelModules = [ "nct6775" ];

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

      boot.kernel.sysctl = {
        "vm.swappiness" = 180;
        "vm.page-cluster" = 0;
        "vm.vfs_cache_pressure" = 50;
      };
    };
}
