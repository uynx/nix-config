{
  description = "Nix configuration for my computers";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-weekly/*";
    nixpkgs-stable.url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-26.05-chilled/*";
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
    # Last revision carrying linux-asahi 7.0.13. The next one moves to 7.1.5,
    # which the Fedora userspace Steam runs in cannot talk to — muvm fails with
    # "could not connect vdrm" and every game dies. Unpin once Fedora ships a
    # 7.1 stack (still virglrenderer 1.3.0 / muvm 0.6.0 as of 2026-08).
    nixos-apple-silicon = {
      url = "github:nix-community/nixos-apple-silicon/3902c801519264191a7c3dfec8dd1f9faeb38fd5";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Home Manager installs .app bundles into the store, where Spotlight and the
    # Dock cannot see them; this generates the aliases that make them launchable.
    mac-app-util = {
      url = "github:hraban/mac-app-util";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Dendritic
    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";
    wrapper-modules = {
      url = "github:BirdeeHub/nix-wrapper-modules";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nvf = {
      url = "github:NotAShelf/nvf";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    obscuravpn = {
      url = "github:Sovereign-Engineering/obscuravpn-client";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
}
