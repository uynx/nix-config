{ self, inputs, ... }:
{
  flake.nixosModules.nixSettings = {
    imports = [ inputs.determinate.nixosModules.default ];

    nixpkgs.overlays = [ self.lib.determinateNixOverlay ];

    nixpkgs.config.allowUnfree = true;
    nix = {
      nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];

      registry = self.lib.selfRegistry self.lib.user.home;

      gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 7d";
      };
      settings = {
        auto-optimise-store = true;
        trusted-users = [ self.lib.user.name ];
        substituters = self.lib.caches.substituters;
        trusted-public-keys = self.lib.caches.publicKeys;
      };
    };
  };
}
