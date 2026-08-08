{ self, inputs, ... }:
{
  flake.nixosModules.nixSettings = {
    # Imported here rather than by each host: the option below is meaningless
    # without it, and a host should not have to know that.
    imports = [ inputs.determinate.nixosModules.default ];

    determinate.enable = true;
    nixpkgs.config.allowUnfree = true;
    nix = {
      # Without this, `nix-shell -p` and `nix repl '<nixpkgs>'` resolve against
      # a channel this config never sets, so they disagree with the flake.
      nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];

      registry = self.lib.selfRegistry self.lib.user.home;

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
        substituters = self.lib.caches.substituters;
        trusted-public-keys = self.lib.caches.publicKeys;
      };
    };
  };
}
