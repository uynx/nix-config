{ self, inputs, ... }:
{
  flake.nixosConfigurations.arm = inputs.nixpkgs.lib.nixosSystem {
    system = "aarch64-linux";
    specialArgs = { inherit inputs; };
    modules = with self.nixosModules; [
      core
      hardwareArm
      homeManagerBase

      desktopNiri
      shell
      programming
      ai
      secrets
      privacy
      cloud
      web
      media
      comms
      office
      latex
      android
      (self.lib.gaming "fex")

      virt

      { networking.hostName = "arm"; }
    ];
  };
}
