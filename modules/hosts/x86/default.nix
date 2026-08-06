{ self, inputs, ... }:
{
  # STUB. Generate hardware-configuration.nix on the machine, drop it in beside
  # this file, and uncomment the import below.
  flake.nixosConfigurations.x86 = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = { inherit inputs; };
    modules = with self.nixosModules; [
      core
      hardwareX86
      homeManagerBase

      # ./_hardware-configuration.nix
      inputs.determinate.nixosModules.default

      { networking.hostName = "x86"; }
      {
        home-manager.users.${self.lib.user.name}.imports = with self.homeModules; [ programming ];
      }
    ];
  };
}
