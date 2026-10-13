{ self, moduleWithSystem, ... }:
{
  flake = {
    wrappers.noctalia-shell =
      { wlib, pkgs, ... }:
      {
        imports = [ wlib.wrapperModules.noctalia-shell ];

        package = pkgs.noctalia-shell.overrideAttrs (_: {
          postInstall = ''
            substituteInPlace $out/share/noctalia-shell/Modules/LockScreen/LockScreenPanel.qml \
              --replace-fail 'isSelected ? Color.mOnPrimary : Color.mPrimary' \
                             'isSelected ? Color.mOnPrimary : Color.mOnSurface'
          '';
        });

        colors = builtins.fromJSON (builtins.readFile ./Flexoki.json);

        preInstalledPlugins.kbd-backlight.src = "${./kbd-backlight}";

        env.NOCTALIA_CONFIG_DIR = pkgs.lib.mkForce "${self.lib.user.home}/.config/noctalia/";
      };

    nixosModules.noctalia = moduleWithSystem (
      { self', ... }:
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
              };
              wantedBy = [ "lock.target" ];
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
                ExecStart = "${self'.packages.noctalia-shell}/bin/noctalia-shell ipc call sessionMenu lock";
              };
            };
          };
        };
      }
    );

    homeModules.noctalia = moduleWithSystem (
      { self', ... }:
      { config, ... }:
      let
        generated = self'.packages.noctalia-shell.generatedConfig;
      in
      {
        home.packages = [ self'.packages.noctalia-shell ];

        # The panel writes straight into the repo file through this symlink.
        # settings.json must keep hooks.screenUnlock = "loginctl unlock-session", or lock.target latches active for the boot.
        xdg.configFile = {
          "noctalia/settings.json".source =
            config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix-config/modules/apps/noctalia/settings.json";
          "noctalia/colors.json".source = "${generated}/colors.json";
          "noctalia/plugins.json".source = "${generated}/plugins.json";
          "noctalia/plugins".source = "${generated}/plugins";
        };

        shellHooks.rebPostSwitch = ''
          if type -q niri; and niri msg version >/dev/null 2>&1
              pkill -f '[q]uickshell -p .*noctalia-shell'
              sleep 1
              niri msg action spawn -- noctalia-shell
          end
        '';

        # noctalia's fallback icon name; blank, so a missing icon shows nothing instead of a checkerboard.
        xdg.dataFile."icons/hicolor/scalable/apps/application-x-executable.svg".source =
          ./application-x-executable.svg;
      }
    );
  };
}
