{ self, ... }:
{
  flake.nixosModules.gaming =
    (self.lib.mkBundle {
      nixos = [ self.nixosModules.steamAsahi ];
      home = [ self.homeModules.steamAsahi ];
    }).nixos;

  flake.nixosModules.gamingArm =
    (self.lib.mkBundle {
      nixos = [ self.nixosModules.steamArm ];
      home = [
        self.homeModules.x86Emu
        self.homeModules.steamArm
        { x86Runner = "fex"; }
      ];
    }).nixos;

  flake.nixosModules.gamingNative =
    (self.lib.mkBundle {
      nixos = [
        self.nixosModules.steamNative
        self.nixosModules.lact
      ];
    }).nixos;
}
