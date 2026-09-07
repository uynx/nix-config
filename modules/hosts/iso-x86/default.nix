{ self, inputs, ... }:
{
  # The x86 twin of `hosts/iso`, and graphical where that one is not: with a
  # browser on the stick the Bitwarden web vault is reachable, so the age key
  # restore and the Claude Code login stop being paste-from-a-phone flows.
  # GNOME because it is one import and carries gparted and firefox already.
  #
  # Nothing here can be built without `boot.binfmt.emulatedSystems` on the
  # asahi host — there is no x86_64 builder in this house.
  # Build: nix build .#nixosConfigurations.iso-x86.config.system.build.isoImage
  flake.nixosConfigurations.iso-x86 = inputs.nixpkgs.lib.nixosSystem {
    specialArgs = { inherit inputs; };
    modules = [
      "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-graphical-gnome.nix"

      # Not the legacy `system =` argument: the installer config branches on
      # `nixpkgs.hostPlatform.system`, which that argument never sets.
      { nixpkgs.hostPlatform.system = "x86_64-linux"; }

      # Not `core`: an installer wants nothing from fonts, bluetooth or the
      # user module. This is the one line that carries determinate plus the
      # substituters, which is the whole reason to build a custom image.
      self.nixosModules.nixSettings

      (
        { pkgs, lib, ... }:
        {
          # Every local build here runs under qemu, and level 19 is the one
          # knob that costs hours rather than minutes. 6 is ~10% larger.
          isoImage.squashfsCompression = "zstd -Xcompression-level 6";

          # Config-specific, so it is never substituted — a long emulated build
          # for HTML that duplicates what nixos.org serves. mkForce because
          # profiles/installation-device.nix deliberately forces it on.
          documentation.nixos.enable = lib.mkForce false;

          # /etc is the store-backed copy; the symlink is what puts it where the
          # autologin lands, since the live home is a tmpfs the store cannot write.
          environment.etc."REINSTALL.md".source = ../../../REINSTALL.md;
          systemd.tmpfiles.rules = [ "L+ /home/nixos/REINSTALL.md - - - - /etc/REINSTALL.md" ];

          # claude-code is a Bun binary that keeps its own interpreter, so it
          # cannot start without nix-ld. Bare rather than `self.nixosModules.nixLd`:
          # that module's library list is for GUI blobs and none of it is needed here.
          programs.nix-ld.enable = true;

          environment.systemPackages =
            with pkgs;
            [
              vim
              git
              gh
              bitwarden-cli
              jq
              sops
              rage
              cryptsetup
              curl
              ripgrep
              fd
            ]
            ++ [
              (pkgs.callPackage ../../apps/brave-origin/_brave-origin.nix { })
              (pkgs.callPackage ../../apps/ai-tools/_ai-clis.nix { }).claude-code
            ];
        }
      )
    ];
  };
}
