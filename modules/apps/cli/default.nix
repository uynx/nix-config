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
      # comma's option only exists once this module is loaded; importing it here
      # rather than via the host keeps the feature working on any host.
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
          # Only as a POSIX interpreter to write scripts against. Do not point
          # environment.binsh at it — third-party /bin/sh scripts use bashisms.
          dash
        ]
        # fetch is Linux-only in nixpkgs, and this module reaches darwin too.
        ++ lib.optional stdenv.hostPlatform.isLinux fetch;

      # nh reads this instead of taking a flake path on every invocation.
      home.sessionVariables.NH_FLAKE = "${config.home.homeDirectory}/nixos-config";

      programs = {
        # Not wrapped, for the same reason as git: a devshell's bat should still
        # see this.
        bat = {
          enable = true;
        }
        # Linux only, and not because of the package: on darwin `programs.ghostty`
        # is enabled, and its module already registers the syntax and a
        # map-syntax for the real ~/.config path. Linux runs the wrapped ghostty
        # out of home.packages, so nothing does it there. The glob needs `**` —
        # `*` does not cross a `/`, which is why the module's own mapping never
        # fired when it was reached through a store symlink.
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
        sioyek.enable = true;
        nix-index.enable = true;
        nix-index-database.comma.enable = true;

        # Home Manager ships no man package on darwin, where this only warns.
        man.generateCaches = pkgs.stdenv.hostPlatform.isLinux;

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
          # Flexoki Dark, matching ghostty and neovim.
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
