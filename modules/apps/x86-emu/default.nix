{
  flake.homeModules.x86Emu =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.x86Apps = lib.mkOption {
        default = { };
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              name = lib.mkOption { type = lib.types.str; };
              exec = lib.mkOption { type = lib.types.str; };
              icon = lib.mkOption { type = lib.types.str; };
            };
          }
        );
      };

      config = {
        home.packages = lib.mapAttrsToList (
          bin: app:
          pkgs.writers.writeDashBin bin ''
            home=${config.xdg.dataHome}/x86-apps/${bin}
            mkdir -p "$home"
            # steam-asahi-stop greps for x86-apps/ to keep this shared VM alive; flags must match steam-asahi-run's
            exec ${pkgs.distrobox}/bin/distrobox enter --no-tty --no-workdir steam-asahi -- \
              /usr/bin/muvm -i --gpu-mode=venus --execute-pre=/usr/local/libexec/steam-guest-tune \
              -e HOME="$home" -e XDG_CONFIG_HOME="$home/.config" -e XDG_DATA_HOME="$home/.local/share" \
              -e XDG_CACHE_HOME="$home/.cache" -e XDG_STATE_HOME="$home/.local/state" \
              -- ${app.exec} "$@" </dev/null
          ''
        ) config.x86Apps;

        xdg.desktopEntries = lib.mapAttrs (bin: app: {
          inherit (app) name icon;
          exec = "${bin} %U";
          terminal = false;
        }) config.x86Apps;
      };
    };
}
