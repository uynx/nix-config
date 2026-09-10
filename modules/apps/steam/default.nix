{ self, ... }:
{
  flake.nixosModules.steamAsahi = {
    virtualisation.docker.enable = true;
    users.users.${self.lib.user.name}.extraGroups = [ "docker" ];
  };
}
