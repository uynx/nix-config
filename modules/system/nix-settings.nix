{ self, inputs, ... }:
{
  flake.nixosModules.nixSettings = {
    determinate.enable = true;
    nixpkgs.config.allowUnfree = true;
    nix = {
      # Without this, `nix-shell -p` and `nix repl '<nixpkgs>'` resolve against
      # a channel this config never sets, so they disagree with the flake.
      nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];

      # `nix run uynx#btop` from any directory, no flake path needed.
      registry.${self.lib.user.name}.to = {
        type = "git";
        url = "file://${self.lib.user.home}/nixos-config";
      };

      gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 7d";
      };
      settings = {
        auto-optimise-store = true;
        trusted-users = [
          "root"
          self.lib.user.name
        ];
        substituters = [
          "https://nix-community.cachix.org"
          "https://numtide.cachix.org"
        ];
        trusted-public-keys = [
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          "numtide.cachix.org-1:2ps1kLBUWnL9yCkD69XfYIa2VclDuxsBeE266mGrW0o="
        ];
      };
    };
  };
}
