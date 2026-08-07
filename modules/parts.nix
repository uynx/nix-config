{ inputs, lib, ... }:
{
  # Same reason as the imports below: `flake.lib` is not a declared option, so
  # `modules/lib/user.nix` and `modules/lib/bundle.nix` would collide rather
  # than merge. Declaring it makes it an ordinary mergeable attrset.
  options.flake.lib = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.raw;
    default = { };
  };

  # Declare flake.homeModules, flake.darwinModules and flake.wrappers as real
  # flake-parts options. flake-parts declares nixosModules itself but not these,
  # and an undeclared flake output can only be defined once — a second module
  # setting it is a merge error, not an override. Wrapped programs also appear
  # as packages.*.<name>.
  imports = [
    inputs.home-manager.flakeModules.home-manager
    inputs.nix-darwin.flakeModules.default
    inputs.wrapper-modules.flakeModules.wrappers
  ];

  # Architectures perSystem is evaluated for; unrelated to which hosts exist.
  config.systems = [
    "aarch64-linux" # asahi, arm
    "x86_64-linux" # x86
    "aarch64-darwin" # darwin
  ];
}
