{
  flake.homeModules.prismlauncher =
    {
      pkgs,
      lib,
      ...
    }:
    let
      inherit (pkgs.stdenv.hostPlatform) isLinux;
    in
    {
      home.packages = lib.optional isLinux pkgs.prismlauncher;
    };
}
