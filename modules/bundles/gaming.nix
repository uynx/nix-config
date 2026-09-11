{ self, ... }:
{
  flake.nixosModules.gaming =
    (self.lib.mkBundle {
      nixos = [ self.nixosModules.steamAsahi ];
      home = [ self.homeModules.steamAsahi ];
    }).nixos;

  flake.nixosModules.gamingNative =
    (self.lib.mkBundle {
      nixos = [
        self.nixosModules.steamNative
        self.nixosModules.lact
      ];
    }).nixos;
}
