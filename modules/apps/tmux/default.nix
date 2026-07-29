{
  # Config lives here as text rather than a symlink out to ~/dotfiles, so a
  # fresh machine gets a working tmux from this repo alone. Plugin paths are
  # store paths, which also removes the old dependency on ~/.nix-profile
  # having been populated first.
  flake.homeModules.tmux =
    { pkgs, ... }:
    let
      plugin = name: "${pkgs.tmuxPlugins.${name}}/share/tmux-plugins/${name}/${name}.tmux";
    in
    {
      home.packages = [ pkgs.tmux ];

      home.file.".config/tmux/tmux.conf".text = ''
        # Prefix Key (Ctrl-a)
        set -g prefix C-a
        unbind C-b
        bind C-a send-prefix

        # Vi Mode Keys
        setw -g mode-keys vi

        # Copy Mode & Clipboard Integration
        bind-key -T copy-mode-vi v send-keys -X begin-selection
        bind-key -T copy-mode-vi y send-keys -X copy-selection-and-cancel

        # True color and undercurl support for Ghostty
        set -g default-terminal "tmux-256color"
        set -ag terminal-overrides ",xterm-256color:RGB"
        set -as terminal-overrides ',*:Smulx=\E[4::%p1%dm'
        set -as terminal-overrides ',*:Setcx=\E[58::2::%p1%{65536}%/%d::%p1%{256}%/%{255}%&%d::%p1%{255}%&%d%;m'

        # Flexoki. Transparent backgrounds inherit Ghostty's window opacity.
        set -g status-style "bg=#252320,fg=#cecdc3"
        set -g message-style "bg=default,fg=#cecdc3"
        set -g status-left "#[fg=#205ea6,bold] #S #[fg=#343331]| "
        set -g status-left-length 20
        set -g status-right ""
        set -g status-right-length 50
        set -g window-status-format "#[fg=#878580] #I: #W "
        set -g window-status-current-format "#[fg=#bc5215,bold,bg=#282726] #I: #W* "
        set -g pane-border-style "fg=#282726"
        set -g pane-active-border-style "fg=#205ea6"

        set -g mouse on
        set -s escape-time 0
        set -g base-index 1
        setw -g pane-base-index 1
        set -g renumber-windows on
        set -g set-clipboard on
        set -s extended-keys on
        set -as terminal-features 'xterm*:extkeys'

        run-shell ${plugin "sensible"}
        run-shell ${plugin "vim-tmux-navigator"}
        set -g @resurrect-strategy-nvim 'session'
        run-shell ${plugin "resurrect"}
        set -g @continuum-restore 'on'
        set -g @continuum-save-interval '10'
        run-shell ${plugin "continuum"}
      '';
    };
}
