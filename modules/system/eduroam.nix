{
  # UMass Amherst eduroam, decoded from the university's own SecureW2 profile
  # rather than guessed: EAP-TTLS with PAP inner auth against clearpass.it.umass.edu.
  #
  # PAP sends the NetID password in cleartext inside the TLS tunnel, and the
  # pinned CAs are public roots that sell certificates to anyone, so
  # `domain-suffix-match` is the only thing between a rogue "eduroam" AP and the
  # password. Do not drop it, and do not swap the pin for the system CA bundle.
  #
  # Credentials come from the `eduroam-env` sops secret, decrypted to /run as
  # root-only and substituted by envsubst at unit start, so the store and git
  # hold only ciphertext. Its plaintext is exactly two lines:
  #   EDUROAM_IDENTITY=<netid>@umass.edu
  #   EDUROAM_PASSWORD=<netid password>
  # Rotating the NetID password means re-editing the secret and rebuilding —
  # until then the connection fails, it does not fall back.
  flake.nixosModules.eduroam =
    { config, pkgs, ... }:
    {
      sops.secrets.eduroam-env = { };

      # NM converts a profile into iwd's format only when it sees that profile as
      # NEW. A rebuild that changes a setting below rewrites /run and reloads, which
      # NM treats as merely modified — it keeps using the stale
      # /var/lib/iwd/eduroam.8021x, so the change silently never reaches the daemon
      # that owns the interface. Clearing both files and making NM forget the
      # profile first is what makes this module actually declarative rather than
      # declarative-until-the-next-reboot.
      # Its preStart deletes an iwd file and expects NM to rewrite it, so iwd
      # must already be running.
      systemd.services.NetworkManager-ensure-profiles.after = [ "iwd.service" ];

      systemd.services.NetworkManager-ensure-profiles.preStart = ''
        rm -f /var/lib/iwd/eduroam.8021x /run/NetworkManager/system-connections/eduroam.nmconnection
        ${pkgs.networkmanager}/bin/nmcli connection reload || true
      '';

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
      };
    };
}
