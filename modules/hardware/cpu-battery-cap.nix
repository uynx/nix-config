_: {
  flake.nixosModules.cpuBatteryCap =
    { lib, pkgs, ... }:
    let
      cap = pkgs.writeShellApplication {
        name = "cpu-battery-cap";
        runtimeInputs = [ pkgs.coreutils ];
        text = builtins.readFile ./cpu-battery-cap.sh;
      };
    in
    {
      systemd.services.cpu-battery-cap = {
        description = "Cap the performance cores while on battery";
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = lib.getExe cap;
        };
      };

      services.udev.extraRules = ''
        SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ACTION=="change", TAG+="systemd", ENV{SYSTEMD_WANTS}+="cpu-battery-cap.service"
      '';
    };
}
