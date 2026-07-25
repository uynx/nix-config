{ inputs, ... }:
{
  flake.nixosConfigurations.uynx = inputs.nixpkgs.lib.nixosSystem {
    system = "aarch64-linux";
    specialArgs = { inherit inputs; };
    modules = [
      ./_configuration.nix
      inputs.determinate.nixosModules.default
      inputs.nixos-apple-silicon.nixosModules.apple-silicon-support
      inputs.home-manager.nixosModules.home-manager
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
