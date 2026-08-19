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

      # Gates the whole module, so the per-format switches under it are moot.
      documentation.enable = false;
      time.timeZone = "America/Chicago";

      launchd.daemons.sntp-sync = {
        serviceConfig = {
          ProgramArguments = [
            "/bin/sh"
            "-c"
            "for i in $(seq 1 30); do /usr/bin/sntp -sS time.apple.com && exit 0; sleep 2; done"
          ];
          RunAtLoad = true;
          StartInterval = 3600;
        };
      };

      # nix-darwin's own counter, unrelated to NixOS' system.stateVersion.
      system.stateVersion = 6;
    };
}
