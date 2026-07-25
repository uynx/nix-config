{
  config,
  pkgs,
  lib,
  pkgs-stable,
  inputs,
  ...
}:

let
  H = "${pkgs.hyprland}/bin/hyprctl";
  J = "${pkgs.jq}/bin/jq";
  home = "/home/uynx";
in
{
  home = {
    username = "uynx";
    homeDirectory = home;
    stateVersion = "26.05";
    file.".local/bin/dictate".source = config.lib.file.mkOutOfStoreSymlink "${home}/dotfiles/scripts/maintenance/dictate";
    sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      PROTON_PASS_KEY_PROVIDER = "fs";
      GSK_RENDERER = "gl";
    };
    sessionPath = [
      "${home}/.grok/bin"
      "${home}/.local/bin"
    ];
    pointerCursor = {
      enable = true;
      gtk.enable = true;
      x11.enable = true;
      package = pkgs.capitaine-cursors;
      name = "capitaine-cursors";
      size = 24;
    };
    packages = with pkgs; [
      wl-clipboard
      wtype
      sox
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
      (neovim.override {
        withNodeJs = true;
        withPython3 = true;
      })
      tree-sitter
      nodejs
      rustc
      (python3.withPackages (
        ps: with ps; [
          pip
          setuptools
        ]
      ))
      gnumake
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
      (pkgs-stable.texlive.withPackages (
        ps: with ps; [
          scheme-full
          biber
        ]
      ))
      proton-vpn
      proton-pass-cli
      qbittorrent
      wireshark
      swi-prolog
      libreoffice
      cava
      socat
      tmux
      tmuxPlugins.sensible
      tmuxPlugins.vim-tmux-navigator
      tmuxPlugins.resurrect
      tmuxPlugins.continuum
      obs-studio
      vesktop
      v4l-utils
      mpv
      fetch
    ];
    file = {
      ".config/nvim".source = config.lib.file.mkOutOfStoreSymlink "${home}/dotfiles/nvim";
      ".local/share/nvim/site/parser/norg.so".source =
        "${pkgs.tree-sitter-grammars.tree-sitter-norg}/parser";
      ".config/ghostty/config".text = ''
        config-file = ${home}/dotfiles/ghostty_config
        font-size = 12
      '';
      ".config/fuzzel/fuzzel.ini".source =
        config.lib.file.mkOutOfStoreSymlink "${home}/dotfiles/fuzzel/fuzzel.ini";
      ".config/waybar".source = config.lib.file.mkOutOfStoreSymlink "${home}/dotfiles/waybar";
      ".config/tmux".source = config.lib.file.mkOutOfStoreSymlink "${home}/dotfiles/tmux";
      ".agents/skills".source = config.lib.file.mkOutOfStoreSymlink "${home}/dotfiles/skills";
      ".agents/AGENTS.md".source = config.lib.file.mkOutOfStoreSymlink "${home}/dotfiles/AGENTS.md";
      ".config/cava/config".text = ''
        [general]
        bars = 16
        framerate = 60
        [input]
        method = pipewire
        source = auto
        [output]
        method = raw
        raw_target = /dev/stdout
        data_format = ascii
        ascii_max_range = 7
      '';
    };
    activation.copilotBridge = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      AUTH_DB="${home}/.config/github-copilot/auth.db"
      HOSTS_JSON="${home}/.config/github-copilot/hosts.json"
      if [ -f "$AUTH_DB" ]; then
        TOKEN=$(${pkgs.sqlite}/bin/sqlite3 "$AUTH_DB" "SELECT cast(token_ciphertext as text) FROM oauth_tokens LIMIT 1;" 2>/dev/null)
        if [ -n "$TOKEN" ]; then
          mkdir -p "$(dirname "$HOSTS_JSON")"
          printf '{\n  "github.com": {\n    "oauth_token": "%s"\n  }\n}\n' "$TOKEN" >"$HOSTS_JSON"
          chmod 600 "$HOSTS_JSON"
        fi
      fi
    '';
    activation.createRequiredDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p \
        "${home}/ai_memory/concepts" \
        "${home}/ai_memory/journal" \
        "${home}/dotfiles" \
        "${home}/nixos-config" \
        "${home}/.local/share/antigravity"
    '';
    activation.installGrok = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -f "${home}/.grok/bin/grok" ]; then
        ${pkgs.curl}/bin/curl -fsSL https://x.ai/cli/install.sh | ${pkgs.bash}/bin/bash || true
      fi
    '';
    activation.installCodex = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -f "${home}/.local/bin/codex" ]; then
        ${pkgs.nodejs}/bin/npm install -g --prefix ${home}/.local @openai/codex || true
      fi
    '';
    activation.installClaude = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -f "${home}/.local/bin/claude" ]; then
        ${pkgs.curl}/bin/curl -fsSL https://claude.ai/install.sh | ${pkgs.bash}/bin/bash || true
      fi
    '';
    activation.installWhisperCpp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -f "${home}/.local/bin/whisper-cli" ]; then
        mkdir -p "${home}/.local/share/whisper.cpp" "${home}/.local/bin"
        export PATH="${pkgs.gzip}/bin:${pkgs.gnutar}/bin:${pkgs.curl}/bin:${pkgs.coreutils}/bin:$PATH"
        curl -fsSL https://github.com/ggml-org/whisper.cpp/releases/download/v1.9.1/whisper-bin-ubuntu-arm64.tar.gz | tar -xz -C "${home}/.local/share/whisper.cpp" --strip-components=1
        ln -sf "${home}/.local/share/whisper.cpp/whisper-cli" "${home}/.local/bin/whisper-cli"
      fi
    '';
  };

  gtk = {
    enable = true;
    gtk3.extraConfig.gtk-application-prefer-dark-theme = true;
    gtk4.extraConfig.gtk-application-prefer-dark-theme = true;
  };

  dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";

  programs = {
    gh = {
      enable = true;
      settings = {
        git_protocol = "ssh";
        editor = "nvim";
      };
    };
    ghostty.enable = true;
    waybar.enable = true;
    fastfetch.enable = true;
    bun.enable = true;
    lazydocker.enable = true;
    java.enable = true;
    cargo.enable = true;
    vscodium.enable = true;
    man = {
      enable = true;
      generateCaches = true;
    };
    zoxide.enable = true;
    yazi = {
      enable = true;
      shellWrapperName = "y";
      settings.manager = {
        show_hidden = true;
        sort_by = "modified";
        sort_dir_first = true;
      };
    };
    bat.enable = true;
    eza = {
      enable = true;
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
    atuin.enable = true;
    fish = {
      enable = true;
      interactiveShellInit = ''
        set -g fish_greeting ""
        fish_vi_key_bindings
      '';
      functions.reb.body = ''
        set -l target "uynx"
        if test (count $argv) -gt 0; set target $argv[1]; end
        sudo nixos-rebuild switch --flake ~/nixos-config#$target --impure
      '';
      functions.pass-find.body = ''
        if not pass-cli test >/dev/null 2>&1
            pass-cli test
            or return 1
        end
        pass-cli item list Personal --output json | jq -r '(.items // .)[] | "[\((.item_type // .itemType // .type // "unknown") | ascii_upcase)] \(.title // .name)\t\(.id // .item_id // .itemId)"' | fzf --ansi --header="Select an item to view credentials" --with-nth=1 | string split \t | read -l display_name id
        if test -n "$id"
            pass-cli item view --vault-name Personal --item-id $id
        end
      '';
      shellAliases = {
        update = "update-brave-origin && nix flake update --flake ~/nixos-config";
        word = "libreoffice --writer";
        powerpoint = "libreoffice --impress";
        gen = "nix-env --list-generations";
        wt = "git worktree list";
        wta = "git worktree add";
        wtr = "git worktree remove";
        vi = "nvim";
        vim = "nvim";
        tree = "eza --tree --icons";
        ll = "eza -la --icons --group-directories-first --header --git-ignore";
        pf = "pass-find";
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
      settings = {
        add_newline = false;
        command_timeout = 3000;
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
    };
    delta = {
      enable = true;
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

}
