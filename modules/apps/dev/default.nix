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

      # devenv vendors its own secretspec (same 0.17.0); adding the standalone
      # package back collides on bin/secretspec and fails the home-manager env.
      devenv

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
