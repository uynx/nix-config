{
  description = "Asahi NixOS — uynx";

  inputs = {
    # System
    nixpkgs.url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-weekly/*";
    nixpkgs-stable.url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-26.05-chilled/*";
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
    # Pinned to the last revision carrying linux-asahi 7.0.13. The following
    # revision moves to 7.1.5, which the Fedora Asahi userspace this machine
    # runs Steam through cannot talk to yet: muvm's GPU setup fails with
    # "could not connect vdrm" and the VM dies, taking every game with it.
    # Fedora's virglrenderer is still 1.3.0 and muvm still 0.6.0, so there is
    # nothing newer to move the container to. Unpin once they ship a 7.1 stack.
    nixos-apple-silicon = {
      url = "github:nix-community/nixos-apple-silicon/3902c801519264191a7c3dfec8dd1f9faeb38fd5";
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
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Dendritic
    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";
    wrapper-modules = {
      url = "github:BirdeeHub/nix-wrapper-modules";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Neovim configured through Nix options instead of Lua. Built as a
    # standalone package alongside the existing LazyVim setup, not in place of
    # it -- see apps/nvim-nvf/ for why both exist for now.
    nvf = {
      url = "github:NotAShelf/nvf";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
}
