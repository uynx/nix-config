{ self, inputs, ... }:
let
  c = self.lib.flexoki;
in
{
  flake.homeModules.cli =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
      imports = [ inputs.nix-index-database.homeModules.nix-index ];

      home.packages =
        with pkgs;
        [
          dust
          duf
          procs
          sd
          gping
          doggo
          tokei
          hyperfine
          bandwhich
          socat
          nh
          nvd
          dash
        ]
        ++ lib.optional stdenv.hostPlatform.isLinux fetch;

      home.sessionVariables.NH_FLAKE = "${config.home.homeDirectory}/nix-config";

      programs = {
        bat = {
          enable = true;
        }
        // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
          syntaxes.ghostty = {
            src = "${pkgs.ghostty}/share/bat/syntaxes";
            file = "ghostty.sublime-syntax";
          };
          config.map-syntax = [ "**/ghostty/config:Ghostty Config" ];
        };

        jq.enable = true;
        zoxide.enable = true;
        atuin.enable = true;
        fastfetch.enable = true;
        sioyek = {
          enable = true;
          config = {
            "control_click_command" = "synctex_under_cursor";
            "inverse_search_command" = ''nvim --headless -c "VimtexInverseSearch %2 '%1'"'';
          };
        };
        nix-index.enable = true;
        nix-index-database.comma.enable = true;

        man.generateCaches = pkgs.stdenv.hostPlatform.isLinux;

        fish.shellAliases = {
          tree = "eza --tree --icons";
          ll = "eza -la --icons --group-directories-first --header --git-ignore";
        };

        eza = {
          enable = true;
          icons = "auto";
          git = true;
          extraOptions = [
            "--group-directories-first"
            "--header"
          ];
        };

        fd = {
          enable = true;
          hidden = true;
        };

        tealdeer = {
          enable = true;
          settings.updates.auto_update = true;
        };

        fzf = {
          enable = true;
          changeDirWidget.command = "fd --type d --hidden --strip-cwd-prefix --exclude .git";
          historyWidget.command = "";
          colors = {
            "bg+" = c.selection;
            bg = c.bg;
            fg = c.gray;
            "fg+" = c.fg;
            hl = c.yellow;
            "hl+" = c.yellow;
            info = c.green;
            marker = c.cyan;
            pointer = c.red;
            prompt = c.blue;
            spinner = c.magenta;
            header = c.dim;
            border = c.dim;
          };
        };

        ripgrep = {
          enable = true;
          arguments = [
            "--max-columns=150"
            "--max-columns-preview"
            "--hidden"
            "--glob=!.git/*"
            "--smart-case"
          ];
        };

        direnv = {
          enable = true;
          package = pkgs.direnv.overrideAttrs (_: {
            doCheck = false;
          });
          nix-direnv.enable = true;
        };
      };
    };
}
