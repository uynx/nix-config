{ inputs, ... }:
{
  # These declare flake.homeModules and flake.darwinModules as real flake-parts
  # options. flake-parts declares nixosModules itself but not those two, and an
  # undeclared flake output can only be defined once — a second module setting
  # it is a merge error, not an override.
  imports = [
    inputs.home-manager.flakeModules.home-manager
    inputs.nix-darwin.flakeModules.default

    # Declares flake.wrappers, where a program's config is baked into its own
    # derivation instead of being written to ~/.config. A wrapped program is a
    # normal package, so it also lands in packages.<system>.<name> and can be
    # run on any machine with `nix run` without leaving a config file behind.
    inputs.wrappers.flakeModules.wrappers
  ];

  # Architectures perSystem blocks get evaluated for. This is about package
  # outputs, not about which machines exist — a host's architecture comes from
  # its own `nixosSystem { system = ...; }`.
  config.systems = [
    "aarch64-linux" # asahi, arm
    "x86_64-linux" # x86
    "aarch64-darwin" # darwin
  ];
}
