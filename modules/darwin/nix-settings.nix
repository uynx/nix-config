{ self, inputs, ... }:
{
  # The darwin twin of `system/nix-settings.nix`. Determinate owns nix.conf on
  # macOS, so the settings go through `determinateNix.customSettings` — the
  # plain `nix.settings` options are refused while it is enabled.
  flake.darwinModules.nixSettings = {
    imports = [ inputs.determinate.darwinModules.default ];

    nixpkgs.config.allowUnfree = true;

    # `determinateNix.enable` defaults to true, same as the NixOS side.
    determinateNix = {
      determinateNixd.garbageCollector.strategy = "automatic";
      customSettings = {
        auto-optimise-store = true;
        trusted-users = [
          "root"
          self.lib.user.name
        ];
        extra-substituters = self.lib.caches.substituters;
        extra-trusted-public-keys = self.lib.caches.publicKeys;
      };
    };

    # Both of these are `nix.*` options on the NixOS side, and both are dead
    # here: the determinate module sets `nix.enable = mkForce false`, so
    # nix-darwin writes neither /etc/nix/registry.json nor NIX_PATH. Home
    # Manager's user-level equivalents are what is left.
    home-manager.users.${self.lib.user.name}.nix = {
      registry = self.lib.selfRegistry self.lib.user.darwinHome;
      nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
    };
  };
}
