{ inputs, ... }:
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
        # Ghostty ships the syntax but not the mapping. The glob needs `**` —
        # `*` does not cross a `/`, which is why the mapping ghostty's own
        # Home Manager module used to add never actually fired. nixpkgs has no
        # darwin ghostty, so the syntax can only be pulled in on Linux.
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

        man = {
          enable = true;
          # Home Manager ships no man package on darwin, where this only warns.
          generateCaches = pkgs.stdenv.hostPlatform.isLinux;
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
          # Flexoki Dark, matching ghostty and neovim.
          colors = {
            "bg+" = "#403e3c";
            bg = "#100f0f";
            fg = "#878580";
            "fg+" = "#cecdc3";
            hl = "#d0a215";
            "hl+" = "#d0a215";
            info = "#879a39";
            marker = "#3aa99f";
            pointer = "#d14d41";
            prompt = "#4385be";
            spinner = "#ce5d97";
            header = "#575653";
            border = "#575653";
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
