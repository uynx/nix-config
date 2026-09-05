{
  # The GL-SFT1200 travel router. Declared for one reason: to pin
  # autoconnect-priority above eduroam's. Left imperative, both profiles sit at
  # priority 0 and NetworkManager falls through to its next tiebreaker, most
  # recently used — so the router only "wins" until the laptop associates with
  # eduroam once, and after a reinstall neither has a timestamp and it is a
  # race. Priority is the only part of this that is deterministic.
  #
  # The PSK comes from the `uynx-env` sops secret, same mechanism as eduroam:
  # decrypted to /run as root-only and substituted at unit start, so the store
  # and git hold only ciphertext. Its plaintext is exactly one line:
  #   UYNX_PSK=<router wifi password>
  # Changing the router's password means re-editing the secret and rebuilding.
  flake.nixosModules.uynxWifi =
    { config, ... }:
    {
      sops.secrets.uynx-env = { };

      networking.networkmanager.ensureProfiles = {
        environmentFiles = [ config.sops.secrets.uynx-env.path ];

        profiles.uynx = {
          connection = {
            id = "uynx";
            # The uuid the imperative profile already carries, so this adopts it
            # rather than creating a second profile for the same SSID.
            uuid = "0702ffcb-d8e6-484c-9ba0-44ee46490570";
            type = "wifi";
            # eduroam declares none, which means 0. Anything above that settles
            # the order without depending on which network was last joined.
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
