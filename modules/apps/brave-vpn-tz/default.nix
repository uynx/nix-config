{
  flake.homeModules.braveVpnTz =
    { pkgs, ... }:
    let
      daemon = pkgs.writers.writePython3Bin "brave-vpn-tz" {
        libraries = [ pkgs.python3Packages.timezonefinder ];
      } (builtins.readFile ./brave_vpn_tz.py);
    in
    {
      systemd.user.services.brave-vpn-tz = {
        Unit = {
          Description = "Keep Brave's time zone on the VPN exit's";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };
        Install.WantedBy = [ "graphical-session.target" ];
        Service = {
          ExecStart = "${daemon}/bin/brave-vpn-tz";
          Environment = "PATH=/run/current-system/sw/bin";
          Restart = "always";
          RestartSec = 5;
        };
      };
    };
}
