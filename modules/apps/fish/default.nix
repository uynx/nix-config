{ moduleWithSystem, ... }:
let
  fishOverlay = moduleWithSystem (
    { self', ... }:
    {
      nixpkgs.overlays = [ (_: _: { fish = self'.packages.fish; }) ];
    }
  );
in
{
  flake.wrappers.fish =
    {
      wlib,
      pkgs,
      lib,
      ...
    }:
    let
      inherit (pkgs.stdenv.hostPlatform) isDarwin;
    in
    {
      imports = [ wlib.wrapperModules.fish ];

      flags."--no-config" = false;

      plugins = [ { src = pkgs.fishPlugins.plugin-sudope; } ];

      shellAliases = {
        gen = "nix-env --list-generations";
      }
      // lib.optionalAttrs isDarwin {
        unb = "xattr -d com.apple.quarantine";
      };

      configFile.content = ''
        set -g fish_greeting ""
        fish_vi_key_bindings
        ${lib.optionalString isDarwin ''
          fish_add_path /opt/homebrew/bin
        ''}
      '';
    };

  flake.nixosModules.fish = fishOverlay;
  flake.darwinModules.fish = fishOverlay;

  flake.homeModules.shellHooks =
    { lib, ... }:
    {
      options.shellHooks = {
        update = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [ "update-ai-clis" ];
          description = ''
            Pin updaters `update` runs concurrently before relocking. They must
            write disjoint files; any failure aborts before relocking.
          '';
        };
        rebPostSwitch = lib.mkOption {
          type = lib.types.lines;
          default = "";
          description = ''
            Fish run by `reb` after a successful switch and before the
            checkpoint commit. For units a switch cannot restart itself.
          '';
        };
      };
    };

  flake.homeModules.fish = moduleWithSystem (
    { self', ... }:
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      inherit (pkgs.stdenv.hostPlatform) isDarwin;

      updateTools = lib.optionalString (config.shellHooks.update != [ ]) ''
        if test (count $argv) -eq 0
            sh -c 'd=$(mktemp -d); n=0
              for c; do
                n=$((n + 1))
                { { sh -c "$c"; echo $? >"$d/$n"; } 2>&1 | while IFS= read -r l; do printf "[%s] %s\n" "$c" "$l"; done; } &
              done
              wait; ! grep -qvx 0 "$d"/*; r=$?; rm -rf "$d"; exit $r' _ ${lib.escapeShellArgs config.shellHooks.update}
            or return 1
        end
      '';
    in
    {
      programs.fish = {
        enable = true;
        package = self'.packages.fish;

        functions = {
          update.body = ''
            ${updateTools}
            nix flake update --flake ~/nix-config --commit-lock-file $argv
          '';

          reb.body = ''
            set -l target ${if isDarwin then "darwin" else "$hostname"}
            set -l platform ${if isDarwin then "darwin" else "os"}
            set -l repo ~/nix-config
            if test (count $argv) -gt 0; set target $argv[1]; end

            git -C $repo add -A
            ${lib.optionalString isDarwin ''
              if test -f /opt/homebrew/bin/agy -a ! -L /opt/homebrew/bin/agy
                  rm -f /opt/homebrew/bin/agy
              end
            ''}
            if nh $platform switch $repo -H $target -- --impure
                ${config.shellHooks.rebPostSwitch}
                if not git -C $repo diff --cached --quiet
                    git -C $repo commit -q -m "rebuild "(date '+%Y-%m-%d %H:%M:%S')
                    echo "Committed as "(git -C $repo rev-parse --short HEAD)
                end
            else
                echo "Rebuild failed. Changes are staged but not committed."
                return 1
            end
          '';
          bg.body = ''
            if test (count $argv) -eq 0
                builtin bg
                return
            end
            xdg-open $argv &>/dev/null &
            disown
          '';
        };
      };

      # fish registers `complete --exclusive bg` for the builtin, which kills path completion.
      xdg.configFile."fish/completions/bg.fish".text = ''
        complete -c bg -e
        complete -c bg -F
      '';
    }
  );
}
