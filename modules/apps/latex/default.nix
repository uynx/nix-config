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
