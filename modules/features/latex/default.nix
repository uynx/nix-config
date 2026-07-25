{ inputs, ... }:
{
  # texlive comes from the stable channel to avoid constant recompiles.
  # Imported here rather than taken from a host-provided extraSpecialArg, so
  # this feature works on any host and any architecture on its own.
  flake.homeModules.latex =
    { pkgs, ... }:
    let
      pkgs-stable = import inputs.nixpkgs-stable {
        inherit (pkgs.stdenv.hostPlatform) system;
        config.allowUnfree = true;
      };
    in
    {
      home.packages = [
        (pkgs-stable.texlive.withPackages (
          ps: with ps; [
            scheme-full
            biber
          ]
        ))
      ];
    };
}
