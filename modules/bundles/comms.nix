{ self, ... }:
{
  # Chat clients. Both are Electron apps nixpkgs builds for Linux only, so the
  # macOS half is casks and shares nothing but the choice itself.
  flake.nixosModules.comms =
    (self.lib.mkBundle {
      home = [ self.homeModules.comms ];
    }).nixos;

  flake.darwinModules.comms =
    (self.lib.mkBundle {
      darwin = [ self.darwinModules.commsCasks ];
    }).darwin;
}
