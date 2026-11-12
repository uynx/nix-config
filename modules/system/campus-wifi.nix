{
  flake.nixosModules.campus-wifi =
    { config, ... }:
    {
      sops.secrets.eduroam-env = { };

      systemd.services.NetworkManager-ensure-profiles = {
        after = [ "iwd.service" ];
        path = [ config.networking.networkmanager.package ];
        environment.CAMPUS_WIFI_ROOT = "/";
        preStart = ''
          rm -f "$CAMPUS_WIFI_ROOT"/etc/NetworkManager/system-connections/{eduroam,uynx}.nmconnection \
            "$CAMPUS_WIFI_ROOT"/run/NetworkManager/system-connections/uynx.nmconnection \
            "$CAMPUS_WIFI_ROOT"/var/lib/iwd/uynx.psk
        '';
        postStart = ''
          # A secret-only reload does not refresh iwd's provisioning file.
          nmcli connection modify --temporary uuid ${config.networking.networkmanager.ensureProfiles.profiles.eduroam.connection.uuid} connection.autoconnect no
          nmcli connection modify --temporary uuid ${config.networking.networkmanager.ensureProfiles.profiles.eduroam.connection.uuid} connection.autoconnect yes
        '';
      };
      sops.secrets.eduroam-env.restartUnits = [ "NetworkManager-ensure-profiles.service" ];

      networking.networkmanager.ensureProfiles = {
        environmentFiles = [ config.sops.secrets.eduroam-env.path ];

        profiles.eduroam = {
          connection = {
            id = "eduroam";
            uuid = "d5dc12a7-ddc7-4911-9f19-64c7cfb208e1";
            type = "wifi";
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
      };
    };
}
