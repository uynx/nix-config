{ moduleWithSystem, ... }:
{
  flake = {
    nixosModules.noctalia = moduleWithSystem (
      _:
      { pkgs, ... }:
      {
        security.pam.services.hyprlock = { };
        systemd = {
          packages = [ pkgs.systemd-lock-handler ];
          user.services = {
            systemd-lock-handler.wantedBy = [ "default.target" ];

            screen-lock = {
              unitConfig = {
                PartOf = [ "lock.target" ];
                After = [ "lock.target" ];
                Before = [ "sleep.target" ];
              };
              wantedBy = [
                "lock.target"
                "sleep.target"
              ];
              serviceConfig = {
                ExecStartPre = "-${pkgs.niri}/bin/niri msg action power-off-monitors";
                ExecStart = "${pkgs.hyprlock}/bin/hyprlock";
                # Only a real unlock releases lock.target; a crash restarts hyprlock, or the screen stays locked with no prompt.
                ExecStopPost = "${pkgs.bash}/bin/sh -c '[ \"$$SERVICE_RESULT\" = success ] && ${pkgs.systemd}/bin/loginctl unlock-session || true'";
                Restart = "on-failure";
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

        config.programs.hyprlock =
          let
            centered = {
              font_family = "Noto Sans";
              halign = "center";
              valign = "center";
            };
          in
          {
            enable = true;
            settings = {
              general = {
                hide_cursor = true;
                ignore_empty_input = true;
              };
              background = [
                {
                  path = "${config.home.homeDirectory}/nix-config/modules/wallpapers/wallpaper.png";
                  blur_passes = 3;
                  blur_size = 8;
                  brightness = 0.55;
                }
              ];
              label = [
                (
                  centered
                  // {
                    text = "";
                    font_family = "Hack Nerd Font";
                    font_size = 54;
                    color = "rgb(ad8a31)";
                    position = "0, 190";
                  }
                )
                (
                  centered
                  // {
                    text = ''cmd[update:1000] ${pkgs.coreutils}/bin/date +"%-I:%M %p"'';
                    font_size = 80;
                    color = "rgb(cecdc3)";
                    position = "0, 70";
                  }
                )
                (
                  centered
                  // {
                    text = ''cmd[update:60000] ${pkgs.coreutils}/bin/date +"%A, %B %-d"'';
                    font_size = 20;
                    color = "rgb(878580)";
                    position = "0, -10";
                  }
                )
              ];
              input-field = [
                {
                  size = "260, 44";
                  position = "0, -90";
                  halign = "center";
                  valign = "center";
                  rounding = -1;
                  outline_thickness = 2;
                  outer_color = "rgba(57565399)";
                  inner_color = "rgba(100f0f99)";
                  font_color = "rgb(cecdc3)";
                  check_color = "rgb(ad8a31)";
                  fail_color = "rgb(d14d41)";
                  dots_size = 0.22;
                  dots_spacing = 0.4;
                  dots_center = true;
                  fade_on_empty = false;
                  placeholder_text = "";
                  fail_text = "";
                }
              ];
            };
          };

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
