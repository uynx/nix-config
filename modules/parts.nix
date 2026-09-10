{ inputs, lib, ... }:
{
  options.flake.lib = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.raw;
    default = { };
  };

  options.flake.darwinModules = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.raw;
    default = { };
  };

  imports = [
    inputs.home-manager.flakeModules.home-manager
    inputs.nix-darwin.flakeModules.default
    inputs.wrapper-modules.flakeModules.wrappers
  ];

  config.systems = [
    "aarch64-linux"
    "x86_64-linux"
    "aarch64-darwin"
  ];

  config.perSystem =
    { pkgs, ... }:
    {
      formatter = pkgs.nixfmt-tree;

      wrappers.packages = lib.genAttrs [
        "ghostty"
        "niri"
        "noctalia-shell"
      ] (_: pkgs.stdenv.hostPlatform.isDarwin);
    };
}
