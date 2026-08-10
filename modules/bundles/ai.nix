{ self, ... }:
let
  bundle = self.lib.mkBundle {
    home = [ self.homeModules.aiTools ];
    # Same tools, different delivery: the pins are aarch64-linux artifacts, so
    # macOS takes the CLIs from Homebrew and adds the desktop apps alongside.
    # Dictation is Wayland-only, so it stays on this side too.
    homeLinux = with self.homeModules; [
      aiToolsPinned
      dictate
      llamaCpp
    ];
    darwin = [ self.darwinModules.aiTools ];
  };
in
{
  flake.nixosModules.ai = bundle.nixos;
  flake.darwinModules.ai = bundle.darwin;
}
