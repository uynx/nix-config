{ config, pkgs, lib, ... }:

{
  home.stateVersion = "25.11";
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
    (python3.withPackages (ps: with ps; [ pynvim pip ]))
    nodejs
    deno
    
    tree-sitter
    ast-grep
    lua5_1
    luajitPackages.luarocks
    
    jdk
    php
    phpPackages.composer
    
    imagemagick
    ghostscript
    tectonic
    mermaid-cli
    texliveBasic
    biber

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

  xdg.configFile."aerospace.toml".source = ./dotfiles/aerospace.toml;
  xdg.configFile."nvim".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix-config/dotfiles/nvim";

  programs = {
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

