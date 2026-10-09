{ ... }:
{
  flake.nixosModules.steamFex = {
    virtualisation.podman.enable = true;
    systemd.user.sockets.podman.wantedBy = [ "sockets.target" ];

    boot.kernel.sysctl."vm.max_map_count" = 2147483642;
  };
}
