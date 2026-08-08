{ self, inputs, ... }:
{
  # The darwin twin of `system/nix-settings.nix`. Determinate owns nix.conf on
  # macOS, so the settings go through `determinateNix.customSettings` — the
  # plain `nix.settings` options are refused while it is enabled.
  flake.darwinModules.nixSettings = {
    imports = [ inputs.determinate.darwinModules.default ];

    nixpkgs.config.allowUnfree = true;

    determinateNix = {
      enable = true;
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

    nix.registry = self.lib.selfRegistry self.lib.user.darwinHome;
  };
}
