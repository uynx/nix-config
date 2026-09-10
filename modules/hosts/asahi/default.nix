{ self, inputs, ... }:
{
  flake.nixosConfigurations.asahi = inputs.nixpkgs.lib.nixosSystem {
    system = "aarch64-linux";
    specialArgs = { inherit inputs; };
    modules = with self.nixosModules; [
      core
      hardwareAsahi
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
      gaming

      virt

      campus-wifi

      ./_hardware-configuration.nix
      inputs.nixos-apple-silicon.nixosModules.apple-silicon-support

      { networking.hostName = "asahi"; }
      {
        boot.binfmt.emulatedSystems = [ "x86_64-linux" ];
      }
      {
        home-manager.users.${self.lib.user.name}.home.sessionVariables.GSK_RENDERER = "gl";
      }
    ];
  };
}
