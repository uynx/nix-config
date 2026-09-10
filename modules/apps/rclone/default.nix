{ self, ... }:
{
  flake.homeModules.rclone =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      mountPoint = "${config.home.homeDirectory}/gdrive";
    in
    {
      imports = [ self.homeModules.sops ];

      systemd.user.services."rclone-mount:@gcrypt" = {
        Unit.X-SwitchMethod = "keep-old";

        Service.ExecStopPost = "-/run/wrappers/bin/fusermount3 -uz ${mountPoint}";
      };

      home.activation.restartRcloneMount = lib.mkIf pkgs.stdenv.hostPlatform.isLinux (
        lib.hm.dag.entryAfter [ "reloadSystemd" ] ''
          run systemctl --user --no-block try-restart rclone-mount:@gcrypt.service || true
        ''
      );

      sops.secrets = {
        rclone-gdrive-token = { };
        rclone-gdrive-client-id = { };
        rclone-gdrive-client-secret = { };
        rclone-crypt-password = { };
        rclone-crypt-salt = { };
      };

      programs.rclone = {
        enable = true;

        remotes = {
          gdrive = {
            config.type = "drive";
            secrets = {
              token = config.sops.secrets.rclone-gdrive-token.path;
              client_id = config.sops.secrets.rclone-gdrive-client-id.path;
              client_secret = config.sops.secrets.rclone-gdrive-client-secret.path;
            };
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
              inherit mountPoint;
              mountType = if pkgs.stdenv.hostPlatform.isDarwin then "nfsmount" else "mount";
            };
          };
        };
      };
    };
}
