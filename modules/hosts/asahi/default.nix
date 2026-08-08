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

      ./_hardware-configuration.nix
      inputs.nixos-apple-silicon.nixosModules.apple-silicon-support

      { networking.hostName = "asahi"; }
      {
        home-manager.users.${self.lib.user.name}.home.sessionVariables.GSK_RENDERER = "gl";
      }
    ];
  };
}
