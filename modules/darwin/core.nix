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

      # `timed` owns the clock and overwrites whatever sntp sets. With no
      # /etc/ntp.conf it has no server to reach ("_address:(null)") and instead
      # extrapolates from its last trusted time plus elapsed counter — which
      # does not count the days this machine spends booted into Asahi. On
      # 2026-09-01 that overwrote an already-correct clock by -609514 s.
      environment.etc."ntp.conf".text = ''
        server 162.159.200.123 iburst
        server 162.159.200.1 iburst
      '';

      # Steps the clock an Asahi session leaves days behind. Cloudflare's NTP
      # anycast IP, because a hostname needs dnscrypt, which needs a valid
      # cert, which needs the clock. `until`, because the `for` loop this
      # replaces ran out before Wi-Fi associated and then exited 0 on its
      # trailing `sleep`. The log is the only per-boot record of the drift.
      launchd.daemons.sntp-sync = {
        serviceConfig = {
          ProgramArguments = [
            "/bin/sh"
            "-c"
            "until /usr/bin/sntp -sS 162.159.200.123; do sleep 10; done"
          ];
          RunAtLoad = true;
          StartInterval = 3600;
          StandardOutPath = "/var/log/sntp-sync.log";
          StandardErrorPath = "/var/log/sntp-sync.log";
        };
      };

      # nix-darwin's own counter, unrelated to NixOS' system.stateVersion.
      system.stateVersion = 6;
    };
}
