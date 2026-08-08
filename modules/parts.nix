{ inputs, lib, ... }:
{
  # Same reason as the imports below: `flake.lib` is not a declared option, so
  # `modules/lib/user.nix` and `modules/lib/bundle.nix` would collide rather
  # than merge. Declaring it makes it an ordinary mergeable attrset.
  options.flake.lib = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.raw;
    default = { };
  };

  # Same again for darwinModules. The nix-darwin flake module imported below
  # declares only `darwinConfigurations`, so this output stayed undeclared and
  # every file after the first to define one collided — as an infinite
  # recursion rather than a merge error, which is a long way from the cause.
  # Values are taken whole, so each module is defined at its own name and never
  # at a path below it.
  options.flake.darwinModules = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.raw;
    default = { };
  };

  # These bring the option declarations this config defines outputs at:
  # home-manager declares flake.homeModules and flake.homeConfigurations,
  # nix-darwin declares flake.darwinConfigurations only (hence the mkOption
  # above), and wrapper-modules declares flake.wrappers. flake-parts declares
  # nixosModules itself. An undeclared flake output can only be defined once —
  # a second module setting it is a merge error, not an override. Wrapped
  # programs also appear as packages.*.<name>.
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

  # Every file here is already nixfmt-clean; without this `nix fmt` is a no-op
  # and says nothing about it.
  config.perSystem =
    { pkgs, ... }:
    {
      formatter = pkgs.nixfmt;
    };
}
