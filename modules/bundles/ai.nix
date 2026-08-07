{ self, ... }:
{
  # Every AI CLI, the shared skills/AGENTS.md wiring and push-to-talk dictation.
  # Not portable as-is: the pinned CLIs are aarch64-linux artifacts and the
  # dictation script is Wayland-only.
  flake.nixosModules.ai = self.lib.mkBundle {
    home = [ self.homeModules.aiTools ];
  };
}
