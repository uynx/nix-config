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

      shell
      programming

      # ./_hardware-configuration.nix

      { networking.hostName = "x86"; }
    ];
  };
}
