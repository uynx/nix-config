{ self, inputs, ... }:
{
  flake.nixosConfigurations.x86 = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = { inherit inputs; };
    modules = with self.nixosModules; [
      core
      hardwareX86
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

      virt
      gamingNative

      ./_hardware-configuration.nix

      { networking.hostName = "x86"; }
    ];
  };
}
