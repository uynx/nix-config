{
  flake.homeModules.rclone =
    { config, ... }:
    let
      secrets = "${config.home.homeDirectory}/.secrets/rclone";
    in
    {
      programs.rclone = {
        enable = true;

        remotes = {
          # rclone-config.service rewrites rclone.conf from this attrset at every
          # login, so anything `rclone config` wrote interactively is lost unless
          # it is carried here. Secrets stay out of the store — and out of this
          # public repo — as files read at service start.
          gdrive = {
            config.type = "drive";
            secrets.token = "${secrets}/gdrive-token";
          };

          gcrypt = {
            config = {
              type = "crypt";
              remote = "gdrive:crypt";
            };
            secrets = {
              password = "${secrets}/crypt-password";
              password2 = "${secrets}/crypt-salt";
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
