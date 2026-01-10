{ config, pkgs, ... }:

{
    home.stateVersion = "25.11";
    home.sessionVariables = {
      DOCKER_HOST = "unix:///Users/uynx/.colima/default/docker.sock";
    };

    xdg.configFile."aerospace/aerospace.toml" = {
      source = ./dotfiles/aerospace.toml;
    };

    programs = {
      fish = {
        enable = true;

    interactiveShellInit = ''
      fish_add_path /opt/homebrew/bin
      set -g fish_greeting ""
    '';
    
    plugins = [];
  };
  starship = {
    enable = true;
    enableFishIntegration = true;
  };
 git = {
    enable = true;
    settings = {
      user = {
        name  = "Brandon Alexander";
        email = "brandonwalex@pm.me";
      };
      init.defaultBranch = "main";
    };
  };
        }; 
# programs = {
#     direnv = {
#       enable = true;
#       nix-direnv.enable = true;
#     };
# 
#     bash = {
#       enable = true;
#       completion.enable = true;
#     };
#     
#     tmux = {
#       enable = true;
#       enableFzf = true;
#       enableSensible = true;
#       enableVim = true;
#     };
# 
#     # gnupg.agent = {
#     #   enable = true;
#     #   enableSSHSupport = true;
#     # };
# 
#   };
}

