{ self, ... }:
let
  bundle = self.lib.mkBundle {
    nixos = [
      {
        # dictate types through ydotool.
        programs.ydotool.enable = true;
        users.users.${self.lib.user.name}.extraGroups = [ "ydotool" ];
      }
    ];
    home = [ self.homeModules.aiTools ];
    homeLinux = with self.homeModules; [
      aiToolsPinned
      dictate
    ];
    darwin = [ self.darwinModules.aiTools ];
  };
in
{
  flake.nixosModules.ai = bundle.nixos;
  flake.darwinModules.ai = bundle.darwin;
}
