{
  flake.nixosModules.personalAssistant =
    { pkgs, ... }:
    let
      simplex = pkgs.callPackage ./_simplex-cli.nix { };
      environment = [
        "AGENT_OWNS_MACHINE=1"
        "PATH=/run/wrappers/bin:/etc/profiles/per-user/uynx/bin:/run/current-system/sw/bin"
      ];
      bridge = "${pkgs.bun}/bin/bun %h/dotfiles/assistant/bridge.ts";
      browserPython = pkgs.python3.withPackages (p: [ p.playwright ]);
      browser = pkgs.writeShellScriptBin "assistant-browser" ''
        export ASSISTANT_EXTENSIONS_DIR="$HOME/.local/share/assistant-extensions"
        exec ${browserPython}/bin/python3 "$HOME/dotfiles/assistant/browser/ab.py" "$@"
      '';
    in
    {
      environment.systemPackages = [
        simplex
        pkgs.protonmail-bridge
        browser
      ];
      home-manager.users.uynx = {
        systemd.user.services = {
          personal-assistant-simplex = {
            Unit.Description = "Personal assistant SimpleX daemon";
            Service = {
              ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p %h/.local/share/personal-assistant/simplex";
              ExecStart = "${pkgs.util-linux}/bin/flock -n -E 0 %t/assistant-simplex.lock ${simplex}/bin/simplex-chat -d %h/.local/share/personal-assistant/simplex/chat -p 5225 --create-bot-display-name BrandonAssistant";
              Restart = "on-failure";
              RestartSec = 5;
              UMask = "0077";
            };
            Install.WantedBy = [ "default.target" ];
          };
          personal-assistant-bridge = {
            Unit = {
              Description = "Durable SimpleX queue for the personal assistant";
              After = [ "personal-assistant-simplex.service" ];
              Wants = [ "personal-assistant-simplex.service" ];
            };
            Service = {
              ExecStart = "${pkgs.util-linux}/bin/flock -n -E 0 %t/assistant-bridge.lock ${bridge} daemon";
              Environment = environment;
              EnvironmentFile = "-%h/.config/personal-assistant/runtime.env";
              Restart = "on-failure";
              RestartSec = 5;
              UMask = "0077";
            };
            Install.WantedBy = [ "default.target" ];
          };
          personal-assistant-session = {
            Unit = {
              Description = "Personal assistant Claude session in its own tmux server";
              After = [ "personal-assistant-bridge.service" ];
              Wants = [ "personal-assistant-bridge.service" ];
            };
            Service = {
              ExecStart = "${pkgs.dash}/bin/dash %h/dotfiles/assistant/session.sh";
              ExecStop = "${pkgs.tmux}/bin/tmux -L personal-assistant kill-server";
              Environment = environment;
              Restart = "always";
              RestartSec = 5;
              UMask = "0077";
            };
            Install.WantedBy = [ "default.target" ];
          };
          personal-assistant-heartbeat = {
            Unit.Description = "Wake the personal assistant for inbox and calendar checks";
            Service = {
              Type = "oneshot";
              ExecStart = "${bridge} heartbeat";
            };
          };
          personal-assistant-rotate = {
            Unit.Description = "Request a fresh personal assistant session and handoff";
            Service = {
              Type = "oneshot";
              ExecStart = "${bridge} rotate";
            };
          };
        };
        systemd.user.timers = {
          personal-assistant-heartbeat = {
            Unit.Description = "Personal assistant heartbeat every twenty minutes";
            Timer = {
              OnBootSec = "5min";
              OnUnitActiveSec = "20min";
            };
            Install.WantedBy = [ "timers.target" ];
          };
          personal-assistant-rotate = {
            Unit.Description = "Fresh personal assistant session at 4 AM Eastern";
            Timer = {
              OnCalendar = "*-*-* 04:00:00 America/New_York";
              Persistent = true;
            };
            Install.WantedBy = [ "timers.target" ];
          };
        };
      };
    };
}
