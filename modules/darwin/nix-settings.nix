{ self, inputs, ... }:
{
  flake.darwinModules.nixSettings = {
    imports = [ inputs.determinate.darwinModules.default ];

    nixpkgs.overlays = [ self.lib.determinateNixOverlay ];

    nixpkgs.config.allowUnfree = true;

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

    home-manager.users.${self.lib.user.name}.nix = {
      registry = self.lib.selfRegistry self.lib.user.darwinHome;
      nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
    };
  };
}
