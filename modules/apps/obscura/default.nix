{ inputs, ... }:
{
  flake.nixosModules.obscura =
    { pkgs, ... }:
    let
      obscura = inputs.obscuravpn.packages.${pkgs.stdenv.hostPlatform.system}.rust-cli-bin;
    in
    {
      environment.systemPackages = [ obscura ];

      # The CLI asks systemd over D-Bus for a unit called exactly "obscura.service"
      # to report status, so renaming this makes it report "not installed".
      systemd.services.obscura = {
        description = "Obscura VPN";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        serviceConfig = {
          ExecStart = "${obscura}/bin/obscura service --dns network-manager";
          # The daemon binds /run/obscura.sock without chowning it, so the socket
          # inherits the unit's group and mode — clients check membership of the
          # owning group, and connecting to a unix socket needs write permission.
          Group = "obscura";
          UMask = "0007";
          StateDirectory = "obscura";
          StateDirectoryMode = "0700";
          Restart = "on-failure";
        };
      };

      users.groups.obscura = { };
    };
}
