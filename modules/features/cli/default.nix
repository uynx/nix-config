{
  flake.homeModules.cli = { pkgs, ... }: {
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
      btop.enable = true;
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
      };

      fzf = {
        enable = true;
        changeDirWidget.command = "fd --type d --hidden --strip-cwd-prefix --exclude .git";
        historyWidget.command = "";
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
