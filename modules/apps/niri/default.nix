{ moduleWithSystem, ... }:
{
  flake.wrappers.niri =
    {
      wlib,
      pkgs,
      lib,
      ...
    }:
    let
      rendered =
        builtins.replaceStrings [ "@xwaylandSatellite@" ] [ (lib.getExe pkgs.xwayland-satellite) ]
          (builtins.readFile ./config.kdl);
    in
    {
      imports = [ wlib.modules.default ];

      package = pkgs.niri;

      passthru.providedSessions = [ "niri" ];

      filesToPatch = [
        "share/applications/*.desktop"
        "share/wayland-sessions/*.desktop"
        "share/systemd/user/*.service"
      ];

      env.NIRI_CONFIG = pkgs.runCommand "niri-config.kdl" { } ''
        cp ${pkgs.writeText "niri-config-unchecked.kdl" rendered} $out
        ${lib.getExe pkgs.niri} validate -c $out
      '';
    };

  flake.nixosModules.niri = moduleWithSystem (
    { self', ... }:
    { pkgs, ... }:
    {
      programs.niri = {
        enable = true;
        package = self'.packages.niri;
      };

      services.upower.enable = true;

      environment.systemPackages = with pkgs; [
        xwayland-satellite
        wl-clipboard
        playerctl
      ];

      xdg.portal = {
        enable = true;
        extraPortals = with pkgs; [
          xdg-desktop-portal-gnome
          xdg-desktop-portal-gtk
        ];
        config.common.default = [
          "gnome"
          "gtk"
        ];
      };
    }
  );

  flake.homeModules.niri =
    { pkgs, lib, ... }:
    {
      shellHooks.rebPostSwitch = ''
        if type -q niri; and niri msg version >/dev/null 2>&1
            set -l niri_cfg (grep -o "/nix/store/[^\" ]*-niri-config.kdl" (type -p niri) | head -n1)
            if test -n "$niri_cfg"
                niri msg action load-config-file --path $niri_cfg
            end
        end
      '';

      home.packages = [
        (pkgs.writers.writeDashBin "close-active" ''
          set -eu

          N=${lib.getExe pkgs.niri}
          ACTIVE=$($N msg -j focused-window 2>/dev/null || echo '{}')
          APP=$(printf '%s' "$ACTIVE" | ${lib.getExe pkgs.jq} -r '.app_id // ""' 2>/dev/null || true)
          case "$APP" in
            steam|Steam|steam_app_[0-9]*)
              if command -v steam-asahi-stop >/dev/null 2>&1; then
                exec steam-asahi-stop
              fi
              ;;
          esac
          exec $N msg action close-window
        '')
      ];
    };
}
