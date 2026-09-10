{ inputs, ... }:
{
  flake.homeModules.latex =
    { pkgs, ... }:
    let
      pkgs-stable = import inputs.nixpkgs-stable {
        inherit (pkgs.stdenv.hostPlatform) system;
        config.allowUnfree = true;
      };
    in
    {
      home.packages = [ pkgs-stable.texliveFull ];
    };
}
