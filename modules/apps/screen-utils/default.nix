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
        wayscriber
        (writers.writeDashBin "toggle-showkeys" ''
          if ${procps}/bin/pgrep -x wshowkeys >/dev/null; then
            exec ${procps}/bin/pkill -x wshowkeys
          fi
          exec /run/wrappers/bin/wshowkeys -t 3 -a top -a right -m 20 -F 'monospace 14'
        '')
        grim
        slurp
        wlrctl
        wtype
      ];
    };
}
