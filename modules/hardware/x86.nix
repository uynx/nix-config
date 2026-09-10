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

      powerManagement.cpuFreqGovernor = "performance";

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

      systemd.services.nvidia-power-limit = {
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${config.hardware.nvidia.package.bin}/bin/nvidia-smi -pl 170";
          RemainAfterExit = true;
        };
      };
    };
}
