{ self, ... }:
{
  # Encrypted Google Drive over rclone. Pulls in `sops` itself rather than
  # relying on the secrets bundle being present, so it works on any host.
  flake.nixosModules.cloud = self.lib.mkBundle {
    home = [ self.homeModules.rclone ];
  };
}
