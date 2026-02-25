{
  description = "My Nix setups";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    neorg-overlay.url = "github:nvim-neorg/nixpkgs-neorg-overlay";
  };

  outputs = inputs @ { self, nixpkgs, nix-darwin, home-manager, neorg-overlay, ... }: {
    darwinConfigurations."macos" = nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      specialArgs = { inherit inputs; };
      modules = [
        ./darwin.nix
        home-manager.darwinModules.home-manager
      ];
    };
  };
}
