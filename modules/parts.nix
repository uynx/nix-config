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

  # nixfmt-tree, not bare nixfmt: `nix fmt` hands the formatter a directory,
  # which nixfmt only still accepts as a deprecated mode — and in it, it tries
  # to parse non-Nix files, dies on the first one and silently leaves the rest
  # of the tree unformatted. The wrapper walks the tree itself.
  config.perSystem =
    { pkgs, ... }:
    {
      formatter = pkgs.nixfmt-tree;

      # A wrapper becomes a package on every system in the list above, and
      # these three wrap Linux-only builds — so on darwin they were outputs
      # that could not evaluate at all, which is `nix flake show` and
      # `nix flake check` failing rather than anything the Mac actually uses.
      # `control_type` defaults to `exclude`, so true here means "do not build".
      wrappers.packages = lib.genAttrs [
        "ghostty"
        "niri"
        "noctalia-shell"
      ] (_: pkgs.stdenv.hostPlatform.isDarwin);
    };
}
