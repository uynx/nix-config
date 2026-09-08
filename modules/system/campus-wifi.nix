{
  # The two halves of the UMass setup: `eduroam` direct, and `uynx` — the
  # GL-SFT1200 travel router that carries eduroam upstream. Both are declared
  # here because their only interesting relationship is which one autoconnect
  # picks, and that is a comparison between the two profiles.
  #
  # eduroam is decoded from the university's own SecureW2 profile rather than
  # guessed: EAP-TTLS with PAP inner auth against clearpass.it.umass.edu.
  #
  # PAP sends the NetID password in cleartext inside the TLS tunnel, and the
  # pinned CAs are public roots that sell certificates to anyone, so
  # `domain-suffix-match` is the only thing between a rogue "eduroam" AP and the
  # password. Do not drop it, and do not swap the pin for the system CA bundle.
  #
  # Credentials come from the `eduroam-env` and `uynx-env` sops secrets,
  # decrypted to /run as root-only and substituted by envsubst at unit start, so
  # the store and git hold only ciphertext. Their plaintext is:
  #   EDUROAM_IDENTITY=<netid>@umass.edu
  #   EDUROAM_PASSWORD=<netid password>
  #   UYNX_PSK=<router wifi passphrase>
  # Rotating either means re-editing the secret and rebuilding — until then the
  # connection fails, it does not fall back.
  flake.nixosModules.campus-wifi =
    { config, ... }:
    {
      sops.secrets.eduroam-env = { };
      sops.secrets.uynx-env = { };

      # Its ordering only matters because NM hands iwd this profile's EAP config;
      # iwd must be up for that to land.
      systemd.services.NetworkManager-ensure-profiles.after = [ "iwd.service" ];

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
            # Deliberately the parent domain, not the server's own name. Under the
            # iwd backend NM rewrites this to iwd's ServerDomainMask by prepending
            # "*.", and "*.clearpass.it.umass.edu" matches only subdomains OF that
            # host, never the host itself — the connection then dies with
            # "Peer certificate's subject domain doesn't match mask". "it.umass.edu"
            # becomes "*.it.umass.edu", which matches the CN and every SAN
            # (clearpass, clearpass1 ... clearpass12).
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
            # Every profile otherwise sits at 0, where autoconnect falls back to
            # whichever candidate was used most recently — and eduroam kept
            # winning the boot. Priority only decides which candidate is picked
            # when NM connects; it never preempts an already-active link, so
            # switching mid-session is still `nmcli connection up uynx`.
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
