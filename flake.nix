{
  description = "Nix configuration for my computers";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-weekly/*";
    nixpkgs-stable.url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-26.05-chilled/*";
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
    # Unpinned 2026-08-13, moving 7.0.13 → 7.1.5. The Fedora Steam container is
    # expected to break on this — its userspace cannot talk to 7.1 and muvm
    # fails with "could not connect vdrm". The Arch container is the reason this
    # is worth trying: asahi-alarm ships its mesa and virglrenderer alongside
    # linux-asahi 7.1.6, so that pairing should hold. Games ran on 7.0.13 under
    # both, so anything that breaks now is the kernel. Roll back by booting the
    # previous generation, or by re-pinning 3902c801.
    nixos-apple-silicon = {
      url = "github:nix-community/nixos-apple-silicon";
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
