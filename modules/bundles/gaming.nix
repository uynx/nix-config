{ self, ... }:
{
  # `(self.lib.gaming "<runner>")` in a host: muvm (16 KiB Apple), fex (4 KiB ARM), native (x86).
  flake.lib.gaming =
    runner:
    (self.lib.mkBundle {
      muvm = {
        nixos = [ self.nixosModules.steamMuvm ];
        home = [ self.homeModules.steamMuvm ];
      };
      fex = {
        nixos = [ self.nixosModules.steamFex ];
        home = [
          self.homeModules.x86Emu
          self.homeModules.steamFex
          { x86Runner = "fex"; }
        ];
      };
      native.nixos = [
        self.nixosModules.steamNative
        self.nixosModules.lact
      ];
    }.${runner}).nixos;
}
