{ self, moduleWithSystem, ... }:
let
  c = self.lib.flexoki;
  # Flexoki surface shades and orange-600, none of which the terminal palette
  # carries an entry for.
  surface = "#252320";
  surfaceAlt = "#282726";
  faint = "#343331";
  orange = "#bc5215";
in
{
  # Config kept verbatim in configAfter rather than re-expressed as the
  # wrapper's typed options: plugin settings only take effect if they are set
  # before that plugin's run-shell, and the typed options give no control over
  # where they land relative to these lines.
  flake.wrappers.tmux =
    { wlib, pkgs, ... }:
    let
      plugin = name: "${pkgs.tmuxPlugins.${name}}/share/tmux-plugins/${name}/${name}.tmux";
    in
    {
      imports = [ wlib.wrapperModules.tmux ];

      sourceSensible = false;

      # The wrapper's own defaults differ from bare tmux, which is what this
      # config ran on before. These four keep the previous behaviour: & and x
      # still ask before killing, the clock stays 12-hour, and passthrough
      # stays off. prefix is set here only so the default C-b binding block is
      # never emitted to fight the one below.
      prefix = "C-a";
      clock24 = false;
      disableConfirmationPrompt = false;
      allowPassthrough = false;

      configAfter = ''
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
        set -g status-style "bg=${surface},fg=${c.fg}"
        set -g message-style "bg=default,fg=${c.fg}"
        set -g status-left "#[fg=${c.blueDeep},bold] #S #[fg=${faint}]| "
        set -g status-left-length 20
        set -g status-right ""
        set -g status-right-length 50
        set -g window-status-format "#[fg=${c.gray}] #I: #W "
        set -g window-status-current-format "#[fg=${orange},bold,bg=${surfaceAlt}] #I: #W* "
        set -g pane-border-style "fg=${surfaceAlt}"
        set -g pane-active-border-style "fg=${c.blueDeep}"

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

  flake.homeModules.tmux = moduleWithSystem (
    { self', ... }:
    { pkgs, ... }:
    {
      home.packages = [
        self'.packages.tmux

        # Sessions are named after the project directory, never after a niri
        # workspace: workspace ids are a compositor counter that drifts and
        # resets, which made every restored session name meaningless.
        (pkgs.writeShellApplication {
          name = "tmux-sessionizer";
          runtimeInputs = [
            self'.packages.tmux
            pkgs.fzf
            pkgs.zoxide
          ];
          text = ''
            dir=$(zoxide query -l | fzf --reverse --height 40%) || exit 0
            name=$(basename "$dir" | tr '.:' '__')

            # Not `start-server`: a server with no sessions exits immediately,
            # and resurrect's restore.sh finds its socket by reading $TMUX, so
            # it only works from inside a session. Hence the throwaway one.
            if ! tmux has-session 2>/dev/null; then
              tmux new-session -d -s resurrect-boot
              tmux run-shell "$(tmux show -gv @resurrect-restore-script-path)"
              tmux kill-session -t resurrect-boot
            fi

            tmux new-session -d -A -s "$name" -c "$dir"
            if [ -n "''${TMUX:-}" ]; then
              exec tmux switch-client -t "$name"
            fi
            exec tmux attach -t "$name"
          '';
        })
      ];
    }
  );
}
