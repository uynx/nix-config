{
  # Docker on macOS, which has no container support of its own — colima runs
  # the daemon inside a Lima VM and exposes the usual socket.
  # bashPackage and dockerPackage stay at their module defaults: `pkgs.bash` is
  # bash-*interactive* on darwin, which is not what colima's internal scripts want.
  flake.homeModules.colima.services.colima.enable = true;
}
