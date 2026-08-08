{ self, ... }:
{
  # The darwin twin of `system/nix-settings.nix`. Determinate owns nix.conf on
  # macOS, so the settings go through `determinateNix.customSettings` — the
  # plain `nix.settings` options are refused while it is enabled.
  flake.darwinModules.nixSettings = {
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
        extra-substituters = [
          "https://nix-community.cachix.org"
          "https://numtide.cachix.org"
        ];
        extra-trusted-public-keys = [
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          "numtide.cachix.org-1:2ps1kLBUWnL9yCkD69XfYIa2VclDuxsBeE266mGrW0o="
        ];
      };
    };

    # `nix run uynx#btop` from any directory, no flake path needed.
    nix.registry.${self.lib.user.name}.to = {
      type = "git";
      url = "file://${self.lib.user.darwinHome}/nixos-config";
    };
  };
}
