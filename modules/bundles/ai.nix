{ self, ... }:
{
  # Every AI CLI, the shared skills/AGENTS.md wiring and push-to-talk dictation.
  flake.nixosModules.ai =
    (self.lib.mkBundle {
      home = with self.homeModules; [
        aiTools
        aiToolsPinned
      ];
    }).nixos;

  # Same tools, different delivery: the pins are aarch64-linux artifacts, so
  # macOS takes the CLIs from Homebrew and adds the desktop apps alongside them.
  flake.darwinModules.ai =
    (self.lib.mkBundle {
      home = [ self.homeModules.aiTools ];
      darwin = [ self.darwinModules.aiTools ];
    }).darwin;
}
