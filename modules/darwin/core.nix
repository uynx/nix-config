{ self, ... }:
{
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
        fish
      ];

      environment.systemPackages = with pkgs; [
        git
        vim
        wget
        curl
      ];

      documentation.enable = false;
      time.timeZone = "America/Chicago";

      environment.etc."ntp.conf".text = ''
        server 162.159.200.123 iburst
        server 162.159.200.1 iburst
      '';

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

      system.stateVersion = 6;
    };
}
