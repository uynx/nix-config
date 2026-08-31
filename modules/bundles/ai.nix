{ self, ... }:
let
  bundle = self.lib.mkBundle {
    home = [ self.homeModules.aiTools ];
    # Same tools, different delivery: the pins are Linux artifacts, so macOS
    # takes the CLIs from Homebrew and adds the desktop apps alongside.
    # Dictation is Wayland-only, so it stays on this side too.
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
