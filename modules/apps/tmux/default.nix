{
  flake.homeModules.tmux =
    { pkgs, ... }:
    let
      plugin = name: "${pkgs.tmuxPlugins.${name}}/share/tmux-plugins/${name}/${name}.tmux";
    in
    {
      home.packages = [
        pkgs.tmux

        # Sessions are named after the project directory, never after a niri
        # workspace: workspace ids are a compositor counter that drifts and
        # resets, which made every restored session name meaningless.
        (pkgs.writeShellApplication {
          name = "tmux-sessionizer";
          runtimeInputs = [
            pkgs.tmux
            pkgs.fzf
            pkgs.zoxide
          ];
          text = ''
            dir=$(zoxide query -l | fzf --reverse --height 40%) || exit 0
            name=$(basename "$dir" | tr '.:' '__')

            # Restore must run before any session exists, and the restore script
            # path only resolves once start-server has loaded the plugins.
            if ! tmux has-session 2>/dev/null; then
              tmux start-server
              tmux run-shell "$(tmux show -gv @resurrect-restore-script-path)"
            fi

            tmux new-session -d -A -s "$name" -c "$dir"
            if [ -n "''${TMUX:-}" ]; then
              exec tmux switch-client -t "$name"
            fi
            exec tmux attach -t "$name"
          '';
        })
      ];

      home.file.".config/tmux/tmux.conf".text = ''
        set -g prefix C-a
        unbind C-b
        bind C-a send-prefix

        setw -g mode-keys vi
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
        set -g @resurrect-capture-pane-contents 'on'
        # Only panes running something other than a shell carry a command, so
        # this is a no-op for most of them. The cost is that a build or a
        # destructive command caught mid-run at save time re-runs on restore.
        set -g @resurrect-processes ':all:'
        run-shell ${plugin "resurrect"}
        # Deliberately no @continuum-restore: continuum restores in the
        # background after a 1s sleep, and only inside a 10s window and a
        # process-count check that any second tmux client silently fails.
        # tmux-sessionizer above restores synchronously instead.
        set -g @continuum-save-interval '10'
        run-shell ${plugin "continuum"}
      '';
    };
}
