{ self, ... }:
{
  flake.nixosModules.steamMuvm = {
    virtualisation.docker.enable = true;
    users.users.${self.lib.user.name}.extraGroups = [ "docker" ];
  };
}
