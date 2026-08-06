{ self, ... }:
{
  flake.homeModules.rclone =
    { config, ... }:
    {
      imports = [ self.homeModules.sops ];

      sops.secrets = {
        rclone-gdrive-token = { };
        rclone-crypt-password = { };
        rclone-crypt-salt = { };
      };

      programs.rclone = {
        enable = true;

        remotes = {
          # rclone-config.service rewrites rclone.conf from this attrset at every
          # login, so anything `rclone config` wrote interactively is lost unless
          # it is carried here. Secrets are read as file paths at service start,
          # which is what lets sops hand them over decrypted at runtime.
          gdrive = {
            config.type = "drive";
            secrets.token = config.sops.secrets.rclone-gdrive-token.path;
          };

          gcrypt = {
            config = {
              type = "crypt";
              remote = "gdrive:crypt";
            };
            secrets = {
              password = config.sops.secrets.rclone-crypt-password.path;
              password2 = config.sops.secrets.rclone-crypt-salt.path;
            };
            mounts."" = {
              enable = true;
              mountPoint = "${config.home.homeDirectory}/gdrive";
            };
          };
        };
      };
    };
}
