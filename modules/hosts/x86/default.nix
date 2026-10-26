{ self, inputs, ... }:
{
  flake.nixosConfigurations.x86 = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = { inherit inputs; };
    modules = with self.nixosModules; [
      standard
      hardwareX86

      # `reb switch` flips ./desktop between niri and kde, then rebuilds and reboots.
      (if builtins.replaceStrings [ "\n" ] [ "" ] (builtins.readFile ./desktop) == "kde" then desktopKde else desktopNiri)
      (self.lib.gaming "native")

      ./_hardware-configuration.nix

      { networking.hostName = "x86"; }
      {
        boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
      }
      (
        let
          key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEUYRYdgXB3O1EvWT1v9pohkK5ylBjpw2aBDViQTia7c";
        in
        {
          services.openssh = {
            enable = true;
            openFirewall = false;
            settings.PasswordAuthentication = false;
            settings.KbdInteractiveAuthentication = false;
          };
          users.users.root.openssh.authorizedKeys.keys = [ key ];
          users.users.${self.lib.user.name}.openssh.authorizedKeys.keys = [ key ];
        }
      )
    ];
  };
}
