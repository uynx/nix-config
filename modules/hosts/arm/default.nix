{ self, inputs, ... }:
{
  # STUB. Generate hardware-configuration.nix on the machine, drop it in beside
  # this file, and uncomment the import below.
  flake.nixosConfigurations.arm = inputs.nixpkgs.lib.nixosSystem {
    system = "aarch64-linux";
    specialArgs = { inherit inputs; };
    modules = with self.nixosModules; [
      core
      hardwareArm
      homeManagerBase

      shell
      programming

      # ./_hardware-configuration.nix

      { networking.hostName = "arm"; }
    ];
  };
}
