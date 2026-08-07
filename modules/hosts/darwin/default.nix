{ self, inputs, ... }:
{
  # macOS on the same MacBook that dual-boots `asahi`. nix-darwin is a separate
  # module system with no boot.loader or systemd, so nothing under
  # modules/system applies — only homeModules cross the boundary.
  # STUB: cannot be built from aarch64-linux. Evaluates only. The real macOS
  # config still lives in ~/nix-darwin-config and is folded in here later.
  flake.darwinConfigurations.darwin = inputs.nix-darwin.lib.darwinSystem {
    system = "aarch64-darwin";
    specialArgs = { inherit inputs; };
    modules = [
      self.darwinModules.homeManagerBase

      {
        networking.hostName = "darwin";
        system.stateVersion = 5;
        nixpkgs.hostPlatform = "aarch64-darwin";
      }
      {
        home-manager.users.${self.lib.user.name}.imports = with self.homeModules; [ programming ];
      }
    ];
  };
}
