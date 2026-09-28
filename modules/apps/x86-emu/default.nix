{
  flake.homeModules.x86Emu =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      pinned = lib.filterAttrs (_: app: app.github != null) config.x86Apps;

      update-x86-apps = pkgs.writers.writeDashBin "update-x86-apps" ''
        set -eu
        export PATH=${
          lib.makeBinPath (
            with pkgs;
            [
              coreutils
              curl
              gnused
              jq
              nix
            ]
          )
        }

        bump() {
          name=$1 repo=$2 path=$3 file=$HOME/nix-config/$4
          current=$(jq -r .version "$file")
          latest=
          for tag in $(curl -fsSL --retry 3 --retry-all-errors --connect-timeout 10 --max-time 30 \
            "https://api.github.com/repos/$repo/releases" | jq -r '.[] | select(.prerelease | not) | .tag_name'); do
            v=''${tag#v}
            u="https://github.com/$repo/releases/download/$(echo "$path" | sed "s/@v@/$v/g")"
            if curl -fsIL --connect-timeout 10 --max-time 30 -o /dev/null "$u"; then
              latest=$v
              break
            fi
          done
          if [ -z "$latest" ]; then
            printf '%-16s SKIPPED (no x86_64 build found)\n' "$name"
          elif [ "$current" = "$latest" ]; then
            printf '%-16s %s (up to date)\n' "$name" "$current"
          else
            hash=$(nix hash convert --hash-algo sha256 --to sri "$(nix-prefetch-url --type sha256 "$u")")
            jq -n --arg v "$latest" --arg h "$hash" '{ version: $v, hash: $h }' >"$file"
            printf '%-16s %s -> %s\n' "$name" "$current" "$latest"
          fi
        }

        ${lib.concatStrings (
          lib.mapAttrsToList (
            name: app: "bump ${name} ${app.github.repo} '${app.github.path}' ${app.github.pins}\n"
          ) pinned
        )}
      '';
    in
    {
      key = "x86Emu";

      options.x86Apps = lib.mkOption {
        default = { };
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              name = lib.mkOption { type = lib.types.str; };
              exec = lib.mkOption { type = lib.types.str; };
              icon = lib.mkOption { type = lib.types.str; };
              github = lib.mkOption {
                default = null;
                type = lib.types.nullOr (
                  lib.types.submodule {
                    options = {
                      repo = lib.mkOption { type = lib.types.str; };
                      path = lib.mkOption { type = lib.types.str; };
                      pins = lib.mkOption { type = lib.types.str; };
                    };
                  }
                );
              };
            };
          }
        );
      };

      config = {
        home.packages =
          lib.mapAttrsToList (
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
          ) config.x86Apps
          ++ lib.optional (pinned != { }) update-x86-apps;

        shellHooks.update = lib.optional (pinned != { }) "update-x86-apps";

        xdg.desktopEntries = lib.mapAttrs (bin: app: {
          inherit (app) name icon;
          exec = "${bin} %U";
          terminal = false;
        }) config.x86Apps;
      };
    };
}
