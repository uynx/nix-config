{ self, inputs, ... }:
{
  flake.nixosConfigurations.arm = inputs.nixpkgs.lib.nixosSystem {
    system = "aarch64-linux";
    specialArgs = { inherit inputs; };
    modules = with self.nixosModules; [
      core
      hardwareArm
      homeManagerBase

      shell
      programming

      { networking.hostName = "arm"; }
    ];
  };
}
