{ self, inputs, ... }:
{
  # STUB. Not installable until a real hardware-configuration.nix is generated
  # on the machine and dropped in beside this file, then uncommented below.
  flake.nixosConfigurations.arm = inputs.nixpkgs.lib.nixosSystem {
    system = "aarch64-linux";
    specialArgs = { inherit inputs; };
    modules = with self.nixosModules; [
      core
      hardwareArm

      # ./_hardware-configuration.nix
      inputs.determinate.nixosModules.default
      inputs.home-manager.nixosModules.home-manager

      { networking.hostName = "arm"; }
      {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          backupFileExtension = "bak";
          extraSpecialArgs = { inherit inputs; };
          users.uynx.imports = with self.homeModules; [ programming ];
        };
      }
    ];
  };
}
