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

      # Per-project: devenv reads devenv.nix from the project directory,
      # secretspec keeps secret names in secretspec.toml and values in the
      # keyring. Neither is configured here; both just need to be on PATH.
      devenv
      secretspec

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
