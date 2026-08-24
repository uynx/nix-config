{
  # UMass Amherst eduroam, decoded from the university's own SecureW2 profile
  # rather than guessed: EAP-TTLS with PAP inner auth against clearpass.it.umass.edu.
  #
  # PAP sends the NetID password in cleartext inside the TLS tunnel, and the
  # pinned CAs are public roots that sell certificates to anyone, so
  # `domain-suffix-match` is the only thing between a rogue "eduroam" AP and the
  # password. Do not drop it, and do not swap the pin for the system CA bundle.
  #
  # Credentials live in /var/lib/secrets/eduroam.env, created empty by tmpfiles
  # and filled in by hand once per machine, like the sops age key. envsubst
  # substitutes them at boot into a 0600 file under /run, so neither the store
  # nor git ever sees them. Until filled in, NetworkManager rejects the profile
  # outright with "802-1x.identity: property is empty" — the file is created
  # empty rather than omitted so the unit still starts.
  #   EDUROAM_IDENTITY=<netid>@umass.edu
  #   EDUROAM_PASSWORD=<netid password>
  flake.nixosModules.eduroam = {
    systemd.tmpfiles.rules = [
      "d /var/lib/secrets 0700 root root -"
      "f /var/lib/secrets/eduroam.env 0600 root root"
    ];

    networking.networkmanager.ensureProfiles = {
      environmentFiles = [ "/var/lib/secrets/eduroam.env" ];

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
          domain-suffix-match = "clearpass.it.umass.edu";
          password = "$EDUROAM_PASSWORD";
        };
        ipv4.method = "auto";
        ipv6.method = "auto";
      };
    };
  };
}
