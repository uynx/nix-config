{
  flake.nixosModules.enteAuth =
    { lib, ... }:
    {
      nixpkgs.overlays = [
        (
          _: prev:
          lib.optionalAttrs (prev.stdenv.hostPlatform.system == "aarch64-linux") {
            aapt = prev.writeShellScriptBin "aapt2" "exit 1";
          }
        )
      ];
    };

  flake.homeModules.enteAuth =
    {
      pkgs,
      lib,
      ...
    }:
    let
      inherit (pkgs.stdenv.hostPlatform) isLinux;
    in
    {
      home.packages = lib.optional isLinux pkgs.ente-auth;
    };
}
