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
    fd
    
    cargo
    rustc
    nodejs
    deno
    
    # Pinned tree-sitter to v0.26.1 for nvim-treesitter compatibility
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
    
    # Provide the latest tree-sitter as a separate command
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
    tectonic
    biber
    texliveSmall
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

  xdg.configFile."aerospace/aerospace.toml".source = ./dotfiles/aerospace.toml;

  xdg.configFile."nvim".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix-config/dotfiles/nvim";
  xdg.dataFile."nvim/site/parser/norg.so".source = "${pkgs.tree-sitter-grammars.tree-sitter-norg}/parser";

  programs = {
    man = {
      enable = true;
      generateCaches = true;
      package = pkgs.man;
    };
    zoxide.enable = true;
    bat.enable = true;
    eza.enable = true;
    fish = {
      enable = true;

      interactiveShellInit = ''
        fish_add_path /opt/homebrew/bin
        set -gx EDITOR nvim
        set -g fish_greeting ""
      '';

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

