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
        dnscrypt
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

      # Cloudflare's NTP anycast IP, not a hostname: dnscrypt rejects Mullvad's
      # cert when the clock is wrong, so resolving here deadlocks. The retry
      # loop this replaces ran out before Wi-Fi associated and exited 0 anyway.
      launchd.daemons.sntp-sync = {
        serviceConfig = {
          ProgramArguments = [
            "/usr/bin/sntp"
            "-sS"
            "162.159.200.123"
          ];
          RunAtLoad = true;
          StartInterval = 300;
        };
      };

      # nix-darwin's own counter, unrelated to NixOS' system.stateVersion.
      system.stateVersion = 6;
    };
}
