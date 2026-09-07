{ self, inputs, ... }:
{
  flake.nixosConfigurations.asahi = inputs.nixpkgs.lib.nixosSystem {
    system = "aarch64-linux";
    specialArgs = { inherit inputs; };
    modules = with self.nixosModules; [
      core
      hardwareAsahi
      homeManagerBase

      # One line per component, both tiers each. Delete a line to drop the
      # component entirely; swap desktopNiri for desktopKde to change desktop.
      desktopNiri
      shell
      programming
      ai
      secrets
      privacy
      cloud
      web
      media
      comms
      office
      latex
      gaming

      # An app module rather than a bundle: it has no Home Manager tier, so
      # wrapping it would only restate the name.
      virt

      # Campus Wi-Fi, laptop only — the other hosts are never at UMass.
      eduroam

      ./_hardware-configuration.nix
      inputs.nixos-apple-silicon.nixosModules.apple-silicon-support

      { networking.hostName = "asahi"; }
      {
        # The only Linux builder here, and the x86 host's ISO and toplevel have
        # to be built somewhere. qemu-user is verified working despite this
        # kernel's 16 KiB pages. Also sets `nix.settings.extra-platforms`.
        boot.binfmt.emulatedSystems = [ "x86_64-linux" ];
      }
      {
        home-manager.users.${self.lib.user.name}.home.sessionVariables.GSK_RENDERER = "gl";
      }
    ];
  };
}
