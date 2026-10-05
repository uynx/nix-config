{ moduleWithSystem, ... }:
{
  flake = {
    wrappers.niri =
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

        # niri has no option for the initial screenshot selection
        package = pkgs.niri.overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [ ./screenshot-full-selection.patch ];
        });

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

    nixosModules.niri = moduleWithSystem (
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

    homeModules.niri =
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
            J=${lib.getExe pkgs.jq}
            ACTIVE=$($N msg -j focused-window 2>/dev/null || echo '{}')
            ID=$(printf '%s' "$ACTIVE" | $J -r '.id // empty')
            APP=$(printf '%s' "$ACTIVE" | $J -r '.app_id // ""')
            $N msg action close-window
            command -v steam-asahi-stop >/dev/null && [ -n "$ID" ] && exec steam-asahi-stop --closed "$ID" "$APP" "$@"
          '')
        ];
      };
  };
}
