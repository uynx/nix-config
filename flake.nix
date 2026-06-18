{
  description = "My Nix setups";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-weekly/*";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixpkgs-stable.url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-26.05-chilled/*";

    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";

    mac-app-util.url = "github:hraban/mac-app-util";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nixpkgs-stable,
      nix-darwin,
      home-manager,
      nix-index-database,
      determinate,
      mac-app-util,
      ...
    }:
    {
      darwinConfigurations."macos" = nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        specialArgs = { inherit inputs; };
        modules = [
          ./darwin.nix
          determinate.darwinModules.default
          home-manager.darwinModules.home-manager
          mac-app-util.darwinModules.default
        ];
      };
    };
}
