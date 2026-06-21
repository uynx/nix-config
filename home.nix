{
  config,
  pkgs,
  pkgs-stable,
  lib,
  ...
}:

{
  imports = [ ];

  home = {
    username = "uynx";
    homeDirectory = "/Users/uynx";
    stateVersion = "26.05";
    sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
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
    tokei
    hyperfine
    bandwhich

    (writeShellScriptBin "memory-sync" ''
      set -euo pipefail
      VAULT_DIR="$HOME/ai_memory"

      if [ ! -d "$VAULT_DIR" ]; then
        echo "Error: AI memory directory $VAULT_DIR does not exist." >&2
        exit 1
      fi

      cd "$VAULT_DIR"
      if [ ! -d .git ]; then
        echo "Error: AI memory directory $VAULT_DIR is not a Git repository." >&2
        exit 1
      fi

      git add .

      if git diff --cached --quiet; then
        echo "No changes to sync."
      else
        if [ $# -gt 0 ] && [ -n "$1" ]; then
          COMMIT_MSG="$1"
          echo "Using provided commit message..."
        else
          echo "Generating commit message..."
          STAGED_FILES=$(git diff --cached --name-only)
          COMMIT_MSG="Updates."

          if echo "$STAGED_FILES" | grep -q 'journal/'; then
            PROJ_NAME=$(echo "$STAGED_FILES" | grep 'journal/' | head -n 1 | sed -E 's|journal/([^0-9]+)_[0-9-]+\.md|\1|' | sed 's/_/ /g')
            PROJ_NAME_CAPS=$(echo "$PROJ_NAME" | awk '{for(i=1;i<=NF;i++)sub(/./,toupper(substr($i,1,1)),$i)}1')
            COMMIT_MSG="Journal: Log daily progress for $PROJ_NAME_CAPS"
          elif echo "$STAGED_FILES" | grep -q 'concepts/'; then
            CONCEPT_NAME=$(echo "$STAGED_FILES" | grep 'concepts/' | head -n 1 | sed -E 's|concepts/(.+)\.md|\1|' | sed 's/_/ /g')
            CONCEPT_NAME_CAPS=$(echo "$CONCEPT_NAME" | awk '{for(i=1;i<=NF;i++)sub(/./,toupper(substr($i,1,1)),$i)}1')
            COMMIT_MSG="Concept: Refine $CONCEPT_NAME_CAPS documentation"
          elif echo "$STAGED_FILES" | grep -q -E 'index.md|projects.md'; then
            COMMIT_MSG="Index: Update vault index and project milestones"
          fi
        fi

        echo "Committing with message: $COMMIT_MSG"
        git commit -m "$COMMIT_MSG"
      fi

      if git remote | grep -q '^origin$'; then
        echo "Pushing changes to remote..."
        git push origin main
      else
        echo "Note: No git remote 'origin' configured. Set one with:"
        echo "  cd $VAULT_DIR && git remote add origin <your-private-repo-url>"
      fi
    '')

    (neovim.override {
      withPerl = true;
      withNodeJs = true;
      withPython3 = true;
      withRuby = true;
    })

    tree-sitter
    rustc
    nodejs
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
    uv

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
    whatsapp-for-mac

    swi-prolog
    sketchybar

    tmux
    tmuxPlugins.sensible
    tmuxPlugins.vim-tmux-navigator
    tmuxPlugins.resurrect
    tmuxPlugins.continuum
  ];

  home.file = {
    ".config/nvim".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix-config/dotfiles/nvim";
    ".local/share/nvim/site/parser/norg.so".source =
      "${pkgs.tree-sitter-grammars.tree-sitter-norg}/parser";

    ".config/ghostty/config".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix-config/dotfiles/ghostty_config";

    ".aerospace.toml".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix-config/dotfiles/aerospace.toml";

    ".config/sketchybar".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix-config/dotfiles/sketchybar";

    ".config/tmux".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix-config/dotfiles/tmux";

    "AGENTS.md".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix-config/dotfiles/AGENTS.md";
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

    antigravity-cli.enable = true;

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
          name = "Brandon Alexander";
          email = "brandonwalex@pm.me";
          signingkey = "~/.ssh/id_ed25519.pub";
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
        commit.gpgsign = true;
        tag.gpgsign = true;
        merge.conflictstyle = "zdiff3";
        rerere.enabled = true;
      };
    };
  };

  home.activation.copilotBridge = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    AUTH_DB="$HOME/.config/github-copilot/auth.db"
    HOSTS_JSON="$HOME/.config/github-copilot/hosts.json"
    if [ -f "$AUTH_DB" ]; then
      TOKEN=$(${pkgs.sqlite}/bin/sqlite3 "$AUTH_DB" "SELECT cast(token_ciphertext as text) FROM oauth_tokens LIMIT 1;" 2>/dev/null)
      if [ -n "$TOKEN" ]; then
        mkdir -p "$(dirname "$HOSTS_JSON")"
        printf '{\n  "github.com": {\n    "oauth_token": "%s"\n  }\n}\n' "$TOKEN" > "$HOSTS_JSON"
        chmod 600 "$HOSTS_JSON"
      fi
    fi
  '';
}
