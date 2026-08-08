{ self, ... }:
{
  # The darwin twin of `system/core.nix`: everything a Mac wants before any
  # bundle is chosen. Same name on purpose — a darwin host's module list reads
  # exactly like a NixOS host's.
  flake.darwinModules.core =
    { pkgs, ... }:
    {
      imports = with self.darwinModules; [
        nixSettings
        defaults
        security
        fonts
        homebrew
        user
        # user.nix makes fish the login shell, so the overlay that points
        # pkgs.fish at the wrapped build has to be in reach of every host.
        fish
      ];

      environment.systemPackages = with pkgs; [
        git
        vim
        wget
        curl
      ];

      documentation = {
        enable = false;
        doc.enable = false;
        man.enable = false;
        info.enable = false;
      };
      system.tools.darwin-uninstaller.enable = false;

      # nix-darwin's own counter, unrelated to NixOS' system.stateVersion.
      system.stateVersion = 6;
    };
}
