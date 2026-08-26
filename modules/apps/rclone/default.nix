{ self, ... }:
{
  flake.homeModules.rclone =
    { config, lib, pkgs, ... }:
    {
      imports = [ self.homeModules.sops ];

      # sd-switch starts changed user units synchronously inside activation, and
      # this one is Type=notify against Google Drive: with no network it blocks
      # for its 90 s start timeout and stalls the whole rebuild. Rebuilding
      # offline is reason enough on its own, so activation must never wait on it.
      systemd.user.services."rclone-mount:@gcrypt".Unit.X-SwitchMethod = "keep-old";

      # keep-old means nothing else ever lands a new rclone on the running mount.
      # This runs on every Home Manager activation rather than only under `reb`,
      # and --no-block keeps it off activation's critical path, so it stays safe
      # on a rebuild with no network at all.
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
          # rclone-config.service rewrites rclone.conf from this attrset at every
          # login, so anything `rclone config` wrote interactively is lost unless
          # it is carried here. Secrets are read as file paths at service start,
          # which is what lets sops hand them over decrypted at runtime.
          # client_id and client_secret belong under `secrets`, not `config`:
          # anything in `config` is rendered into a store path, which is world
          # readable. rclone only obscures options its backend marks as
          # passwords, so these two arrive verbatim, which is what Drive wants.
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
              mountPoint = "${config.home.homeDirectory}/gdrive";
              # nfsmount runs an in-process NFS server and mounts it with the
              # system NFS client, so macOS needs no macFUSE kext and no
              # Recovery-mode security downgrade. Linux keeps plain FUSE, where
              # mounting NFS would want root.
              mountType = if pkgs.stdenv.hostPlatform.isDarwin then "nfsmount" else "mount";
            };
          };
        };
      };
    };
}
