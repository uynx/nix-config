{ self, ... }:
{
  flake.nixosModules.userPassword =
    { config, ... }:
    {
      sops.secrets.user-password.neededForUsers = true;
      users.users.${self.lib.user.name}.hashedPasswordFile = config.sops.secrets.user-password.path;
    };
}
