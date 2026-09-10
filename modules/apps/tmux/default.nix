{ self, moduleWithSystem, ... }:
let
  c = self.lib.flexoki;
  surface = "#252320";
  surfaceAlt = "#282726";
  faint = "#343331";
  orange = "#bc5215";
in
{
  flake.wrappers.tmux =
    { wlib, pkgs, ... }:
    let
      plugin = name: "${pkgs.tmuxPlugins.${name}}/share/tmux-plugins/${name}/${name}.tmux";
    in
    {
      imports = [ wlib.wrapperModules.tmux ];

      sourceSensible = false;

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

        set -g default-terminal "tmux-256color"
        set -ag terminal-overrides ",xterm-256color:RGB"
        set -as terminal-overrides ',*:Smulx=\E[4::%p1%dm'
        set -as terminal-overrides ',*:Setcx=\E[58::2::%p1%{65536}%/%d::%p1%{256}%/%{255}%&%d::%p1%{255}%&%d%;m'

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
        set -g @resurrect-processes ':all:'
        run-shell ${plugin "resurrect"}
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
