{ self, ... }:
{
  flake.nixosModules.assistantSsh = {
    services.openssh = {
      enable = true;
      openFirewall = false;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
      };
    };
    users.users.${self.lib.user.name}.openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEUYRYdgXB3O1EvWT1v9pohkK5ylBjpw2aBDViQTia7c"
    ];
  };
}
