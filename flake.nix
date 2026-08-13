{
  description = "Nix configuration for my computers";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-weekly/*";
    nixpkgs-stable.url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-26.05-chilled/*";
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
    # Last revision carrying linux-asahi 7.0.13. 7.1.5 boots, but no OpenGL
    # survives inside muvm — `muvm -- glxinfo` kills the VM and Steam dies at
    # its first GL call. Both containers, 2026-08-13. Unpin when virglrenderer
    # ships a 7.1 fix.
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

    # Deliberately does NOT follow nixpkgs — do not re-add it. Its rust-overlay
    # follows this input in turn, and against our weekly nixpkgs the toolchain
    # fetch degrades to a source named "unknown" that unpackPhase then refuses:
    # "do not know how to unpack source archive". Costs one extra nixpkgs in
    # the lock, which is the price of a vendored Rust toolchain.
    obscuravpn.url = "github:Sovereign-Engineering/obscuravpn-client";
  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
}
