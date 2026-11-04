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
          set -l pkg (string match -r '/nix/store/[^/]+-noctalia-[^/]+' < (readlink -f (command -v noctalia)))
          if type -q niri; and niri msg version >/dev/null 2>&1; and not begin; test -n "$pkg"; and pgrep -f "$pkg/bin/noctalia" >/dev/null; end
              pkill -x noctalia
              sleep 1
              niri msg action spawn -- noctalia
          end
        '';

        # noctalia's fallback icon name; blank, so a missing icon shows nothing instead of a checkerboard.
        config.xdg.dataFile."icons/hicolor/scalable/apps/application-x-executable.svg".source =
          ./application-x-executable.svg;
      }
    );
  };
}
