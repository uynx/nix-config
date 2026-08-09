{ self, inputs, ... }:
{
  flake.nixosModules.nixSettings = {
    # Imported here rather than by each host, and it enables itself: the
    # module's `determinate.enable` already defaults to true.
    imports = [ inputs.determinate.nixosModules.default ];

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
        # root is the option's own default and this list merges with it.
        trusted-users = [ self.lib.user.name ];
        substituters = self.lib.caches.substituters;
        trusted-public-keys = self.lib.caches.publicKeys;
      };
    };
  };
}
