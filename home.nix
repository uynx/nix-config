{ config, pkgs, lib, ... }:

{
  home.stateVersion = "26.05";
  home.sessionVariables = {
    DOCKER_HOST = "unix:///Users/uynx/.colima/default/docker.sock";
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
    
    cargo
    rustc
    nodejs
    deno
    (python3.withPackages (ps: with ps; [ pip setuptools ]))
    
    # Pinned for LazyVim
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
      patches = []; 
    }))
    
    # Latest tree-sitter in nixpkgs
    (pkgs.writeShellScriptBin "tree-sitter-latest" ''
      exec ${pkgs.tree-sitter}/bin/tree-sitter "$@"
    '')
    
    clang
    ast-grep
    lua5_1
    luarocks
    ruby
    
    jdk
    php
    php.packages.composer
    
    imagemagick
    ghostscript
    (texlive.combine {
      inherit (texlive) 
        scheme-full
        biber;
    })
    mermaid-cli

    aerospace
    discord
    firefox
    qbittorrent
    vscodium
    wireshark

    gemini-cli
    ghostty-bin
    brave
    devpod
  ];
  xdg.configFile."ghostty/config".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix-config/dotfiles/ghostty_config";

  xdg.configFile."aerospace/aerospace.toml".source = ./dotfiles/aerospace.toml;


  xdg.configFile."nvim".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix-config/dotfiles/nvim";
  xdg.dataFile."nvim/site/parser/norg.so".source = "${pkgs.tree-sitter-grammars.tree-sitter-norg}/parser";

  home.file."Library/Application Support/BraveSoftware/Brave-Browser/NativeMessagingHosts/firenvim.json".text = 
    let 
      # Wrapper to ensure PATH is set so Brave can find nvim and its dependencies
      # We use --headless and ensure no intro message to avoid polluting stdout
      firenvim_wrapper = pkgs.writeShellScript "firenvim_nvim" ''
        export PATH="${config.home.homeDirectory}/.nix-profile/bin:/run/current-system/sw/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
        exec ${config.programs.neovim.finalPackage}/bin/nvim --headless --cmd "set shortmess+=I" "$@"
      '';
    in
    builtins.toJSON {
      name = "firenvim";
      description = "Firenvim connector";
      path = "${firenvim_wrapper}";
      type = "stdio";
      allowed_origins = [ "chrome-extension://otdbuclmgnjkpbdaokeojghpneocnban/" ];
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
      };

      plugins = [ ];
    };
    starship = {
      enable = true;
      enableFishIntegration = true;
      settings.command_timeout = 1000;
    };
    neovim = {
      enable = true;
      defaultEditor = true;
      withNodeJs = true;
      withPython3 = true;
      withRuby = true;
      withPerl = true;
      viAlias = true;
      vimAlias = true;
      vimdiffAlias = true;
    };
    fzf.enable = true;
    ripgrep.enable = true;
    lazygit.enable = true;
    jq.enable = true;
    gh.enable = true;
    go.enable = true;
    direnv = {
      enable = true;
      nix-direnv.enable = true;
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

