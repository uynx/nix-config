{
  flake.nixosModules.campus-wifi =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      sops.secrets.eduroam-env = { };
      sops.secrets.uynx-env = { };

      systemd.services.NetworkManager-ensure-profiles.after = [ "iwd.service" ];

      systemd.services.prefer-uynx = lib.mkIf (config.networking.hostName == "asahi") {
        description = "Switch to the travel router when its Wi-Fi is available";
        after = [
          "NetworkManager.service"
          "NetworkManager-ensure-profiles.service"
        ];
        requires = [ "NetworkManager.service" ];
        path = [
          pkgs.networkmanager
          pkgs.gnugrep
        ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.dash}/bin/dash ${./prefer-uynx.sh}";
          TimeoutStartSec = 75;
        };
      };

      systemd.timers.prefer-uynx = lib.mkIf (config.networking.hostName == "asahi") {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "1min";
          OnUnitInactiveSec = "1min";
          AccuracySec = "5s";
        };
      };

      networking.networkmanager.ensureProfiles = {
        environmentFiles = [
          config.sops.secrets.eduroam-env.path
          config.sops.secrets.uynx-env.path
        ];

        profiles.eduroam = {
          connection = {
            id = "eduroam";
            uuid = "d5dc12a7-ddc7-4911-9f19-64c7cfb208e1";
            type = "wifi";
            autoconnect-priority = if config.networking.hostName == "asahi" then 50 else 0;
          };
          wifi = {
            mode = "infrastructure";
            ssid = "eduroam";
          };
          wifi-security.key-mgmt = "wpa-eap";
          "802-1x" = {
            eap = "ttls";
            phase2-auth = "pap";
            identity = "$EDUROAM_IDENTITY";
            anonymous-identity = "anonymous@umass.edu";
            ca-cert = "${./umass-eduroam-ca.pem}";
            domain-suffix-match = "it.umass.edu";
            password = "$EDUROAM_PASSWORD";
          };
          ipv4.method = "auto";
          ipv6.method = "auto";
        };

        profiles.uynx = {
          connection = {
            id = "uynx";
            uuid = "550e7a8e-c569-4b8f-a6f2-fee8c2a1cc1f";
            type = "wifi";
            autoconnect-priority = 100;
          };
          wifi = {
            mode = "infrastructure";
            ssid = "uynx";
          };
          wifi-security = {
            key-mgmt = "wpa-psk";
            psk = "$UYNX_PSK";
          };
          ipv4.method = "auto";
          ipv6.method = "auto";
        };
      };
    };
}
