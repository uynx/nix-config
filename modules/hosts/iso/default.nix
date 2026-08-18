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

      # Bootstraps the flake clone and the age key restore without a
      # `nix-shell` detour. CLI only — the image has no display server, so
      # bitwarden-desktop would just sit unopenable.
      {
        # No display server here, so the runbook has to be readable from a TTY.
        # /etc is the store-backed copy; the symlink is what puts it where the
        # autologin lands, since the live home is a tmpfs the store cannot write.
        # mkForce because profiles/installation-device.nix deliberately forces the
        # NixOS manual on; a plain `false` silently loses to it. It is HTML served
        # by nixos-help and this image has no display server, so it is unreadable
        # weight. Man pages stay — cryptsetup's is worth having in a rescue shell.
        documentation.nixos.enable = inputs.nixpkgs.lib.mkForce false;

        environment.etc."REINSTALL.md".source = ../../../REINSTALL.md;
        systemd.tmpfiles.rules = [ "L+ /home/nixos/REINSTALL.md - - - - /etc/REINSTALL.md" ];

        environment.systemPackages = with inputs.nixpkgs.legacyPackages.aarch64-linux; [
          vim
          git
          gh
          bitwarden-cli
          jq
          sops
          rage
          cryptsetup
          curl
        ];
      }
    ];
  };
}
