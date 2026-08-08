{
  # Docker on macOS, which has no container support of its own — colima runs
  # the daemon inside a Lima VM and exposes the usual socket.
  flake.homeModules.colima =
    { pkgs, ... }:
    {
      services.colima = {
        enable = true;
        bashPackage = pkgs.bash;
        dockerPackage = pkgs.docker;
      };
    };
}
