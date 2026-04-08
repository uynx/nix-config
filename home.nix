{
  config,
  pkgs,
  pkgs-stable,
  inputs,
  ...
}:

{
  imports = [
    inputs.nix-index-database.homeModules.nix-index
  ];

  home = {
    username = "uynx";
    homeDirectory = "/Users/uynx";
    stateVersion = "25.11";
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

    # Pinned for lazy
    (tree-sitter.overrideAttrs (_: rec {
      version = "0.26.7";
      src = pkgs.fetchFromGitHub {
        owner = "tree-sitter";
        repo = "tree-sitter";
        rev = "v0.26.7";
        hash = "sha256-O3c2djKhM+vIYunthDApi9sw/gFH/FBME1uR4N+9MFM="; # 43
      };
      cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
        inherit src;
        hash = "sha256-zh6KsnZ7s6VXGCggoYbLGeGnEZ7g7anjkz8C5/L4yXQ=";
      };
      patches = [ ];
    }))

    # Latest tree-sitter in nixpkgs (potentially more reliable)
    (pkgs.writeShellScriptBin "tree-sitter-latest" ''
      exec ${pkgs.tree-sitter}/bin/tree-sitter "$@"
    '')

    rustc
    nodejs
    deno
    (python3.withPackages (
      ps: with ps; [
        pip
        setuptools
      ]
    ))
    clang
    ast-grep
    lua5_1
    luarocks
    julia-bin
    php
    php.packages.composer
    ruby

    imagemagick
    ghostscript
    mermaid-cli

    nil
    nixfmt
    statix

    (pkgs-stable.texlive.combine {
      inherit (pkgs-stable.texlive)
        scheme-full
        biber
        ;
    })

    melonds
    proton-pass
    qbittorrent
    wireshark

    lima
    devpod
    dive
  ];

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    withNodeJs = true;
    withRuby = true;
    withPython3 = true;
    withPerl = true;
  };

  home.file = {
    ".config/nvim".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix-config/dotfiles/nvim";
    ".local/share/nvim/site/parser/norg.so".source =
      "${pkgs.tree-sitter-grammars.tree-sitter-norg}/parser";

    ".config/ghostty/config".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix-config/dotfiles/ghostty_config";

    ".aerospace.toml".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix-config/dotfiles/aerospace.toml";

    ".gemini/settings.json".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix-config/dotfiles/gemini_settings.json";
  };

  services.colima = {
    enable = true;
    bashPackage = pkgs.bash;
    dockerPackage = pkgs.docker;
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

    gemini-cli.enable = true;

    fastfetch.enable = true;
    bun.enable = true;
    lazydocker.enable = true;
    java.enable = true;
    cargo.enable = true;

    aerospace = {
      enable = true;
      package = pkgs.aerospace;
      launchd = {
        enable = true;
        keepAlive = true;
      };
    };

    vscode = {
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
        set -g fish_greeting ""
        fish_vi_key_bindings
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

        cat = "bat";
        grep = "rg";
        find = "fd";
        sed = "sd";
        ping = "gping";
        top = "btop";
        htop = "btop";
        dig = "doggo";
        du = "dust";
        df = "duf";
        ps = "procs";
        cd = "z";
        zi = "z -i";
        vi = "nvim";
        vim = "nvim";
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
        command_timeout = 1000;
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

    # chromium = {
    #   enable = true;
    #   package = pkgs.ungoogled-chromium;
    # };

    librewolf.enable = true;

    jq.enable = true;
    go.enable = true;
    sioyek.enable = true;
    nix-index.enable = true;
    nix-index-database.comma.enable = true;

    direnv = {
      enable = true;
      nix-direnv.enable = true;
      enableFishIntegration = true;
    };

    git = {
      enable = true;
      settings = {
        user = {
          name = "Brandon Alexander";
          email = "brandonwalex@pm.me";
        };
        init.defaultBranch = "main";
        pull.rebase = true;
        push.autoSetupRemote = true;
        core.editor = "nvim";
      };
    };
  };
}
