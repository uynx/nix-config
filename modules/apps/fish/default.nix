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
            Pin updaters `update` runs before relocking. Each is run in turn and
            the first failure aborts, so nothing relocks on a half-updated pin.
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
            ${lib.concatMapStringsSep "\n    " (c: "${c}; or return 1") config.shellHooks.update}
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
        };
      };
    }
  );
}
