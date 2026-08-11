{ inputs, ... }:
{
  # Stable texlive, to avoid constant recompiles. Imported here rather than
  # taken from a host extraSpecialArg, so this works on any host.
  flake.homeModules.latex =
    { pkgs, ... }:
    let
      pkgs-stable = import inputs.nixpkgs-stable {
        inherit (pkgs.stdenv.hostPlatform) system;
        config.allowUnfree = true;
      };
    in
    {
      # texliveFull, not `texlive.withPackages`: any withPackages set is a
      # locally-combined derivation Hydra never built, so it recompiles on every
      # stable-pin bump. texliveFull is the same full scheme, biber included,
      # and is in cache.nixos.org for aarch64.
      home.packages = [ pkgs-stable.texliveFull ];
    };
}
