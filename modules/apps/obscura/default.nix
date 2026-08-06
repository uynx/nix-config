{ inputs, ... }:
{
  flake.nixosModules.obscura =
    { pkgs, lib, ... }:
    let
      obscura = inputs.obscuravpn.packages.${pkgs.stdenv.hostPlatform.system}.rust-cli-bin;
      obscura-gui = inputs.obscuravpn.packages.${pkgs.stdenv.hostPlatform.system}.rust-gui-bin;

      # rust-gui-bin is only the binary; upstream keeps the launcher and icons in
      # its distro packaging directory, so pull them straight off the flake source.
      obscura-gui-desktop = pkgs.runCommand "obscura-gui-desktop" { } ''
        install -Dm444 ${inputs.obscuravpn}/linux/common/net.obscura.vpn.gui.desktop \
          $out/share/applications/net.obscura.vpn.gui.desktop
        for px in 128 256; do
          install -Dm444 ${inputs.obscuravpn}/linux/common/icons/net.obscura.vpn.gui-$px.png \
            $out/share/icons/hicolor/''${px}x''${px}/apps/net.obscura.vpn.gui.png
        done
      '';
    in
    {
      environment.systemPackages = [
        obscura
        obscura-gui
        obscura-gui-desktop
      ];

      # The CLI asks systemd over D-Bus for a unit called exactly "obscura.service"
      # to report status, so renaming this makes it report "not installed".
      systemd.services.obscura = {
        description = "Obscura VPN";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];

        # auto_connect is daemon-owned state with no CLI or service flag, and the
        # daemon rewrites the whole file on shutdown, so it has to be re-asserted
        # here on every start. Redirecting into the original path rather than
        # renaming a temp file over it keeps the file's mode and owner.
        preStart = ''
          cfg=/var/lib/obscura/config.json
          [ -e "$cfg" ] || exit 0
          patched=$(${lib.getExe pkgs.jq} '.auto_connect = true' "$cfg") \
            && printf '%s' "$patched" > "$cfg"
        '';

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
