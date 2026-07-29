{ inputs, ... }:
{
  flake.homeModules.cli = { pkgs, ... }: {
    # comma needs programs.nix-index-database, which only exists once this
    # module is loaded. Declare it here rather than relying on the host adding
    # it to sharedModules, or this feature silently breaks on any other host.
    imports = [ inputs.nix-index-database.homeModules.nix-index ];

    home.packages = with pkgs; [
      coreutils
      wget
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
      fetch
    ];

    programs = {
      bat.enable = true;

      # btop is not here any more: it is a wrapped package now, and its config
      # and Flexoki theme are baked into the derivation. See apps/btop/.

      jq.enable = true;
      zoxide.enable = true;
      atuin.enable = true;
      fastfetch.enable = true;
      sioyek.enable = true;
      nix-index.enable = true;
      nix-index-database.comma.enable = true;

      man = {
        enable = true;
        generateCaches = true;
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

      yazi = {
        enable = true;
        shellWrapperName = "y";
        settings.manager = {
          show_hidden = true;
          sort_by = "modified";
          sort_dir_first = true;
        };
        # Same story as btop's theme: lifted out of ~/.config into this repo.
        flavors.flexoki = ./flexoki.yazi;
        theme.flavor = {
          dark = "flexoki";
          light = "flexoki";
        };
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

      starship = {
        enable = true;
        settings = {
          add_newline = false;
          command_timeout = 3000;
          # Redefining the standard colour names in a palette retints every
          # module at once, without having to restyle each one individually.
          palette = "flexoki";
          palettes.flexoki = {
            black = "#100f0f";
            red = "#d14d41";
            green = "#879a39";
            yellow = "#d0a215";
            blue = "#4385be";
            purple = "#ce5d97";
            cyan = "#3aa99f";
            white = "#cecdc3";
          };
        };
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
