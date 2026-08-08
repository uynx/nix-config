{ self, inputs, ... }:
{
  # macOS on the same MacBook that dual-boots `asahi`. Reads like the asahi host
  # on purpose: same bundle names, same one-line-per-component rule. The two
  # differ only where macOS has no equivalent — no hardware module, no
  # `desktopNiri`, and `gaming` stays on the Linux side.
  flake.darwinConfigurations.darwin = inputs.nix-darwin.lib.darwinSystem {
    system = "aarch64-darwin";
    specialArgs = { inherit inputs; };
    modules = with self.darwinModules; [
      core
      homeManagerBase

      desktopMacos
      shell
      programming
      ai
      privacy
      web
      media
      comms
      office
      latex

      # Both need this machine's own key added to .sops.yaml and its own
      # secrets/secrets.yaml; until then activation would fail on decryption.
      # secrets
      # cloud

      {
        networking = {
          hostName = "MacBook-Pro";
          computerName = "MacBook-Pro";
        };
        nixpkgs.hostPlatform = "aarch64-darwin";
      }
      {
        home-manager.users.${self.lib.user.name}.home.sessionVariables = {
          EDITOR = "nvim";
          VISUAL = "nvim";
        };
      }
    ];
  };
}
