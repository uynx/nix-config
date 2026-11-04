{ moduleWithSystem, ... }:
{
  flake = {
    nixosModules.noctalia = moduleWithSystem (
      _:
      { pkgs, ... }:
      {
        systemd = {
          packages = [ pkgs.systemd-lock-handler ];
          user.services = {
            systemd-lock-handler.wantedBy = [ "default.target" ];

            noctalia-lock = {
              unitConfig = {
                PartOf = [ "lock.target" ];
                After = [ "lock.target" ];
                # Noctalia's own lockOnSuspend is off so this locks with the screen already dark, before sleep.
                Before = [ "sleep.target" ];
              };
              wantedBy = [
                "lock.target"
                "sleep.target"
              ];
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
                ExecStartPre = "-${pkgs.niri}/bin/niri msg action power-off-monitors";
                ExecStart = "${pkgs.noctalia}/bin/noctalia msg session lock";
              };
            };
          };
        };
      }
    );

    homeModules.noctalia = moduleWithSystem (
      _:
      {
        config,
        pkgs,
        ...
      }:
      {
        config.home.packages = [ pkgs.noctalia ];

        config.xdg.configFile = {
          "noctalia/config.toml".source =
            config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix-config/modules/apps/noctalia/config.toml";
          "noctalia/palettes/Flexoki.json".source = ./Flexoki.json;
        };

        config.shellHooks.rebPostSwitch = ''
          set -l exe (path dirname (path resolve (command -v noctalia)))/.noctalia-wrapped
          set -l palette (path resolve ~/.config/noctalia/palettes/Flexoki.json)
          set -l stamp ~/.local/state/noctalia-palette
          if type -q niri; and niri msg version >/dev/null 2>&1
              # comm is truncated (".noctalia-wrapp", v4's noctalia-qs ".quickshell-wra"), so judge each by its exe.
              for p in (pgrep -x .noctalia-wrapp) (pgrep -x .quickshell-wra)
                  set -l e (path resolve /proc/$p/exe)
                  if string match -q '*noctalia*' -- $e; and test "$e" != "$exe"
                      kill $p
                  end
              end
              sleep 1
              if test "$palette" != "$(cat $stamp 2>/dev/null)"
                  pkill -x .noctalia-wrapp
                  sleep 1
              end
              if not pgrep -x .noctalia-wrapp >/dev/null
                  niri msg action spawn -- env FONTCONFIG_FILE=$HOME/nix-config/modules/apps/noctalia/fonts.conf noctalia
                  echo $palette >$stamp
              end
          end
        '';

        # noctalia's fallback icon name; blank, so a missing icon shows nothing instead of a checkerboard.
        config.xdg.dataFile."icons/hicolor/scalable/apps/application-x-executable.svg".source =
          ./application-x-executable.svg;
      }
    );
  };
}
