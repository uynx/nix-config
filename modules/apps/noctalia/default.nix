{ moduleWithSystem, ... }:
{
  flake = {
    nixosModules.noctalia = moduleWithSystem (
      _:
      { pkgs, ... }:
      {
        nixpkgs.overlays = [
          (_: prev: {
            noctalia = prev.noctalia.overrideAttrs (
              old:
              let
                patch = ./. + "/lock-keyboard-${old.version}.patch";
              in
              {
                # A noctalia bump without a matching patch drops the lock keyboard instead of failing the build.
                patches = (old.patches or [ ]) ++ prev.lib.optional (builtins.pathExists patch) patch;
              }
            );
            wvkbd = prev.wvkbd.overrideAttrs (
              old:
              let
                patch = ./. + "/wvkbd-layout-${old.version}.patch";
              in
              {
                # Replaces the "fullwide" layout with a plain US keyboard; the bar button launches only that layout.
                patches = (old.patches or [ ]) ++ prev.lib.optional (builtins.pathExists patch) patch;
              }
            );
          })
        ];

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
        config.home.packages = [
          pkgs.noctalia
          pkgs.wvkbd
        ];

        config.xdg.configFile = {
          "noctalia/config.toml".source =
            config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix-config/modules/apps/noctalia/config.toml";
          "noctalia/palettes/Flexoki.json".source = ./Flexoki.json;
        };

        config.shellHooks.rebPostSwitch = ''
          set -l exe (path dirname (path resolve (command -v noctalia)))/.noctalia-wrapped
          set -l palette (path resolve ~/.config/noctalia/palettes/Flexoki.json)
          set -l stamp ~/.local/state/noctalia-palette
          # noctalia saves its computed lock layout to settings.toml, which then overrides config.toml's lock widgets.
          set -l state ~/.local/state/noctalia/settings.toml
          if test -f $state
              set -l keep 1
              set -l out
              for l in (cat $state)
                  if string match -qr '^\s*\[' -- $l
                      string match -qr '^\s*\[+"?lockscreen_widgets' -- $l; and set keep 0; or set keep 1
                  end
                  test $keep = 1; and set -a out $l
              end
              printf '%s\n' $out >$state
          end
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
