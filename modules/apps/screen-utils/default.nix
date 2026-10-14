{
  flake.nixosModules.screenUtils =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.showmethekey ];
      programs.wshowkeys = {
        enable = true;
        package = pkgs.wshowkeys.overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [ ./wshowkeys-persist.patch ];
        });
      };
    };

  flake.homeModules.screenUtils =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        (writers.writeDashBin "toggle-showkeys" ''
          if ${procps}/bin/pgrep -x wshowkeys >/dev/null; then
            exec ${procps}/bin/pkill -x wshowkeys
          fi
          exec /run/wrappers/bin/wshowkeys -a right -a top -F 'Hack Nerd Font 20' -s '#d0a215ff' -f '#cecdc3ff' -b '#100f0f66' -m 30 -t 1000
        '')
        grim
        slurp
        wlrctl
        wtype
      ];
    };
}
