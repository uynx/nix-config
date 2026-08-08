{ self, ... }:
let
  bundle = self.lib.mkBundle {
    home = [ self.homeModules.aiTools ];
    # Same tools, different delivery: the pins are aarch64-linux artifacts, so
    # macOS takes the CLIs from Homebrew and adds the desktop apps alongside.
    homeLinux = [ self.homeModules.aiToolsPinned ];
    darwin = [ self.darwinModules.aiTools ];
  };
in
{
  flake.nixosModules.ai = bundle.nixos;
  flake.darwinModules.ai = bundle.darwin;
}
