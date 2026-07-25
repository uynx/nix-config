{
  flake.homeModules.tmux =
    { config, pkgs, ... }:
    let
      home = "/home/uynx";
    in
    {
      home.packages = with pkgs; [
        tmux
        tmuxPlugins.sensible
        tmuxPlugins.vim-tmux-navigator
        tmuxPlugins.resurrect
        tmuxPlugins.continuum
      ];
      home.file.".config/tmux".source =
        config.lib.file.mkOutOfStoreSymlink "${home}/dotfiles/tmux";
    };
}
