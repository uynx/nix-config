{ self, inputs, ... }:
{
  flake.nixosConfigurations.asahi = inputs.nixpkgs.lib.nixosSystem {
    system = "aarch64-linux";
    specialArgs = { inherit inputs; };
    modules = with self.nixosModules; [
      core
      hardwareAsahi
      niri
      sddm
      screenUtils
      steamAsahi

      ./_hardware-configuration.nix
      inputs.determinate.nixosModules.default
      inputs.nixos-apple-silicon.nixosModules.apple-silicon-support
      inputs.home-manager.nixosModules.home-manager

      { networking.hostName = "asahi"; }
      {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          backupFileExtension = "bak";
          extraSpecialArgs = { inherit inputs; };
          users.uynx.imports = with self.homeModules; [
            ./_home.nix
            desktopHome
            programming
            steamAsahi
          ];
        };
      }
    ];
  };
}
