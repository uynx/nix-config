{ self, inputs, ... }:
{
  # Asahi installer ISO with Determinate Nix on it. Determinate's own aarch64
  # ISO cannot boot this hardware — stock kernel, 4 KiB pages, no Apple SoC
  # drivers and no firmware extraction — so the image has to be built here.
  # Build: nix build .#nixosConfigurations.iso.config.system.build.isoImage
  flake.nixosConfigurations.iso = inputs.nixpkgs.lib.nixosSystem {
    specialArgs = { inherit inputs; };
    modules = [
      inputs.nixos-apple-silicon.nixosModules.apple-silicon-installer

      # Not the legacy `system =` argument: the installer config branches on
      # `nixpkgs.hostPlatform.system`, which that argument never sets, and the
      # option then evaluates with no value at all.
      { nixpkgs.hostPlatform.system = "aarch64-linux"; }

      # Not `core`: an installer wants nothing from fonts, bluetooth or the
      # user module. This is the one line that carries determinate plus the
      # substituters, which is the whole reason to build a custom image.
      self.nixosModules.nixSettings
    ];
  };
}
