{
  flake.homeModules.dev = { pkgs, ... }: {
    home.packages = with pkgs; [
      nodejs
      rustc
      (python3.withPackages (
        ps: with ps; [
          pip
          setuptools
        ]
      ))
      gnumake
      lua5_1
      luarocks
      julia-bin
      php
      php.packages.composer
      ruby
      uv
      swi-prolog
      mermaid-cli

      # Per-project dev shells. devenv reads devenv.nix from the project
      # directory, so nothing about it is configured here -- it just needs to
      # be on PATH. secretspec keeps secret *names* in a committed
      # secretspec.toml and the values in the system keyring, which is why it
      # pairs with devenv rather than duplicating it.
      devenv
      secretspec

      # Nix tooling on the CLI. Neovim gets its own copies through nvf, but
      # these are wanted outside the editor too.
      nixfmt
      statix
    ];

    programs = {
      go.enable = true;
      cargo.enable = true;
      java.enable = true;
      bun.enable = true;
      vscodium.enable = true;
      lazydocker.enable = true;
    };
  };
}
