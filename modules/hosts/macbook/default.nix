{ self, inputs, ... }:
{
  flake.nixosConfigurations.macbook = inputs.nixpkgs.lib.nixosSystem {
    system = "aarch64-linux";
    specialArgs = { inherit inputs; };
    modules = with self.nixosModules; [
      core
      hardwareMacbook
      hyprland
      greetd
      steamAsahi

      ./_hardware-configuration.nix
      inputs.determinate.nixosModules.default
      inputs.nixos-apple-silicon.nixosModules.apple-silicon-support
      inputs.home-manager.nixosModules.home-manager

      { networking.hostName = "MacBook-Pro"; }
      {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          backupFileExtension = "bak";
          extraSpecialArgs = {
            inherit inputs;
            pkgs-stable = import inputs.nixpkgs-stable {
              system = "aarch64-linux";
              config.allowUnfree = true;
            };
          };
          sharedModules = [ inputs.nix-index-database.homeModules.nix-index ];
          users.uynx = import ./_home.nix;
        };
      }
    ];
  };
}
