{
  config,
  pkgs,
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
    stateVersion = "26.05";
  };

  targets.darwin.copyApps.enable = false;

  home.sessionVariables = {
    DOCKER_HOST = "unix:///Users/uynx/.colima/default/docker.sock";
    EDITOR = "nvim";
  };

  home.packages = with pkgs; [
    coreutils
    wget
    fastfetch
    dust
    duf
    procs
    sd
    gping
    doggo

    # Pinned for lazy
    (tree-sitter.overrideAttrs (oldAttrs: rec {
      version = "0.26.1";
      src = pkgs.fetchFromGitHub {
        owner = "tree-sitter";
        repo = "tree-sitter";
        rev = "v0.26.1";
        hash = "sha256-k8X2qtxUne8C6znYAKeb4zoBf+vffmcJZQHUmBvsilA=";
      };
      cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
        inherit src;
        hash = "sha256-hnFHYQ8xPNFqic1UYygiLBWu3n82IkTJuQvgcXcMdv0=";
      };
      patches = [ ];
    }))

    # Latest tree-sitter in nixpkgs
    (pkgs.writeShellScriptBin "tree-sitter-latest" ''
      exec ${pkgs.tree-sitter}/bin/tree-sitter "$@"
    '')

    cargo
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
    jdk
    julia-bin
    php
    php.packages.composer
    ruby

    nil
    nixfmt
    statix

    postgresql
    mongodb-tools
    docker
    colima
    lima

    melonds

    imagemagick
    ghostscript
    (texlive.combine {
      inherit (texlive)
        scheme-full
        biber
        ;
    })
    mermaid-cli

    aerospace
    discord
    firefox-bin
    proton-pass
    qbittorrent
    vscodium
    wireshark

    gemini-cli
    ghostty-bin
    brave
    devpod
  ];

  programs.neovim = {
    enable = true;
    withNodeJs = true;
    withRuby = true;
    withPython3 = true;
    withPerl = true;
  };

  home.file = {
    ".config/aerospace/aerospace.toml".source = ./dotfiles/aerospace.toml;
    ".config/ghostty/config".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix-config/dotfiles/ghostty_config";
    ".config/nvim".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix-config/dotfiles/nvim";
    ".local/share/nvim/site/parser/norg.so".source =
      "${pkgs.tree-sitter-grammars.tree-sitter-norg}/parser";
    "Library/Application Support/BraveSoftware/Brave-Browser/NativeMessagingHosts/firenvim.json".text =
      let
        firenvim_wrapper = pkgs.writeShellScript "firenvim_nvim" ''
          export PATH="${config.home.homeDirectory}/.nix-profile/bin:/run/current-system/sw/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
          exec ${pkgs.neovim}/bin/nvim --headless "$@"
        '';
      in
      builtins.toJSON {
        name = "firenvim";
        description = "Firenvim connector";
        path = "${firenvim_wrapper}";
        type = "stdio";
        allowed_origins = [ "chrome-extension://otdbuclmgnjkpbdaokeojghpneocnban/" ];
      };
  };

  programs = {
    man = {
      enable = true;
      generateCaches = true;
      package = pkgs.man;
    };
    zoxide.enable = true;
    bat.enable = true;
    eza.enable = true;
    btop.enable = true;
    fd.enable = true;
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
      '';

      shellAliases = {
        update = "nix flake update --flake ~/nix-config";
        reb = "sudo darwin-rebuild switch --flake ~/nix-config#macos";
        unb = "xattr -d com.apple.quarantine";

        word = "open -a LibreOffice --args --writer";
        powerpoint = "open -a LibreOffice --args --impress";

        cat = "bat";
        grep = "rg";
        find = "fd";
        sed = "sd";
        ping = "gping";
        top = "btop";
        htop = "btop";
        dig = "doggo";
        ls = "eza --icons";
        ll = "eza -lh --icons";
        la = "eza -lah --icons";
        tree = "eza --tree --icons";
        du = "dust";
        df = "duf";
        ps = "procs";
        cd = "z";
        vi = "nvim";
        vim = "nvim";
      };

      plugins = [ ];
    };
    starship = {
      enable = true;
      enableFishIntegration = true;
      settings.command_timeout = 1000;
    };
    fzf.enable = true;
    ripgrep.enable = true;
    lazygit.enable = true;
    jq.enable = true;
    gh.enable = true;
    go.enable = true;
    nix-index.enable = true;
    nix-index-database.comma.enable = true;
    direnv = {
      enable = true;
      nix-direnv.enable = true;
      package = pkgs.direnv.overrideAttrs (old: {
        env = (old.env or { }) // {
          CGO_ENABLED = "1";
        };
      });
    };
    git = {
      enable = true;
      settings = {
        user = {
          name = "Brandon Alexander";
          email = "brandonwalex@pm.me";
        };
        init.defaultBranch = "main";
      };
    };
  };
}
