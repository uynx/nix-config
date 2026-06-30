{
  config,
  pkgs,
  pkgs-stable,
  lib,
  ...
}:

let
  username = "uynx"; # <-- CHANGE THIS to your macOS username
  gitName = "Brandon Alexander"; # <-- CHANGE THIS to your Git name
  gitEmail = "brandonwalex@pm.me"; # <-- CHANGE THIS to your Git email
  gitSigningKey = "~/.ssh/id_ed25519.pub"; # <-- CHANGE THIS to your SSH signing key (or set commit.gpgsign to false below if not signing)
in
{
  imports = [ ];

  home = {
    username = username;
    homeDirectory = "/Users/${username}";
    stateVersion = "26.05";
    sessionVariables = {
      EDITOR = "nano";
      VISUAL = "nano";
    };
  };

  targets.darwin.copyApps.enable = false;
  targets.darwin.linkApps.enable = true;

  home.packages = with pkgs; [
    coreutils
    wget
    dust
    duf
    procs
    sd
    gping
    doggo
    obsidian

    proton-pass
    qbittorrent
    whatsapp-for-mac

    tmux
    tmuxPlugins.sensible
    tmuxPlugins.vim-tmux-navigator
    tmuxPlugins.resurrect
    tmuxPlugins.continuum
  ];

  home.file = {
    ".config/ghostty/config".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix-config/dotfiles/ghostty_config";

    ".config/tmux".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix-config/dotfiles/tmux";
  };



  programs = {
    gh = {
      enable = true;
      settings = {
        git_protocol = "ssh";
        editor = "nvim";
      };
    };

    ghostty = {
      enable = true;
      package = pkgs.ghostty-bin;
    };

    fastfetch.enable = true;
    bun.enable = true;
    lazydocker.enable = true;
    java.enable = true;
    cargo.enable = true;



    vscodium = {
      enable = true;
      package = pkgs.vscodium;
    };

    discord = {
      enable = true;
    };

    man = {
      enable = true;
      generateCaches = true;
      package = pkgs-stable.man;
    };

    zoxide = {
      enable = true;
      enableFishIntegration = true;
    };

    yazi = {
      enable = true;
      enableFishIntegration = true;
      shellWrapperName = "y";
      settings = {
        manager = {
          show_hidden = true;
          sort_by = "modified";
          sort_dir_first = true;
        };
      };
    };

    bat = {
      enable = true;
    };

    eza = {
      enable = true;
      enableFishIntegration = true;
      icons = "auto";
      git = true;
      extraOptions = [
        "--group-directories-first"
        "--header"
      ];
    };

    btop.enable = true;

    fd = {
      enable = true;
      hidden = true;
    };

    tealdeer = {
      enable = true;
      settings.updates.auto_update = true;
    };

    atuin = {
      enable = true;
      enableFishIntegration = true;
    };

    fish = {
      enable = true;

      interactiveShellInit = ''
        fish_add_path /opt/homebrew/bin
        set -g fish_greeting "Welcome! To update system packages, run:
  1. 'update' (fetches latest packages)
  2. 'reb'    (applies configurations and rebuilds system)"
      '';

      shellAliases = {
        update = "nix flake update --flake ~/nix-config";
        reb = "sudo darwin-rebuild switch --flake ~/nix-config#macos";
        unb = "xattr -d com.apple.quarantine";

        word = "open -a LibreOffice --args --writer";
        powerpoint = "open -a LibreOffice --args --impress";

        gen = "nix-env --list-generations";

        wt = "git worktree list";
        wta = "git worktree add";
        wtr = "git worktree remove";

        tree = "eza --tree --icons";
        ll = "eza -la --icons --group-directories-first --header --git-ignore";
      };

      plugins = [
        {
          name = "sudope";
          src = pkgs.fishPlugins.plugin-sudope;
        }
      ];
    };

    starship = {
      enable = true;
      enableFishIntegration = true;
      settings = {
        add_newline = false;
        command_timeout = 3000;
      };
    };

    fzf = {
      enable = true;
      enableFishIntegration = true;
      changeDirWidgetCommand = "fd --type d --hidden --strip-cwd-prefix --exclude .git";
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

    lazygit = {
      enable = true;
      settings = {
        gui.showIcons = true;
        git.paging = {
          colorArg = "always";
          pager = "bat --style=plain";
        };
      };
    };

    chromium = {
      enable = true;
      package = pkgs.brave;
    };

    jq.enable = true;
    go.enable = true;
    sioyek.enable = true;
    nix-index.enable = true;
    nix-index-database.comma.enable = true;

    direnv = {
      enable = true;
      package = pkgs.direnv.overrideAttrs (_: {
        doCheck = false;
      });
      nix-direnv.enable = true;
      enableFishIntegration = true;
    };

    delta = {
      enable = true;
      enableGitIntegration = true;
      options = {
        navigate = true;
        side-by-side = true;
        line-numbers = true;
        theme = "Nord";
      };
    };

    git = {
      enable = true;
      settings = {
        user = {
          name = gitName;
          email = gitEmail;
          signingkey = gitSigningKey;
        };
        init.defaultBranch = "main";
        pull.rebase = true;
        push.autoSetupRemote = true;
        core = {
          editor = "nvim";
          fsmonitor = true;
          untrackedCache = true;
        };
        gpg.format = "ssh";
        commit.gpgsign = false;
        tag.gpgsign = false;
        merge.conflictstyle = "zdiff3";
        rerere.enabled = true;
      };
    };
  };
}
