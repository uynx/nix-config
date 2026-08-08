{ self, ... }:
{
  # Docker backs the Fedora/distrobox container the Steam stack runs in. The
  # group only exists once docker is enabled, so membership belongs here rather
  # than in `system/user.nix`, where a host without this bundle would name a
  # group nothing declares.
  flake.nixosModules.steamAsahi = {
    virtualisation.docker.enable = true;
    users.users.${self.lib.user.name}.extraGroups = [ "docker" ];
  };
}
