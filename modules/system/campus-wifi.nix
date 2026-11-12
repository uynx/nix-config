{
  flake.nixosModules.campus-wifi =
    { config, ... }:
    {
      sops.secrets.eduroam-env = { };

      systemd.services.NetworkManager-ensure-profiles = {
        after = [ "iwd.service" ];
        path = [ config.networking.networkmanager.package ];
        serviceConfig.StateDirectory = "eduroam-profile";
        # iwd keeps the old password unless NM deletes and re-adds the profile; deleting on every run leaves iwd not autoconnecting.
        preStart = ''
          new=$(sha256sum ${config.sops.secrets.eduroam-env.path} | cut -d' ' -f1)
          old=$(cat "$STATE_DIRECTORY/secret.sha256" 2>/dev/null || true)
          if [ -n "$old" ] && [ "$old" != "$new" ]; then
            nmcli connection delete uuid ${config.networking.networkmanager.ensureProfiles.profiles.eduroam.connection.uuid} || true
          fi
          echo "$new" > "$STATE_DIRECTORY/secret.sha256"
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
